import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:home_widget/home_widget.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

const String appVersion = '0.3.7';

// ── Date Feature Color Constants ──────────────────────
const _bgCard       = Color(0xFF16213E);
const _bgElevated   = Color(0xFF1F2B4A);
const _accent       = Color(0xFFE8A598); // rose gold
const _success      = Color(0xFF6EE7B7); // mint
const _textPrimary  = Color(0xFFF0EAF8);
const _textSecondary = Color(0xFF8892B0);
const _dividerColor = Color(0xFF2D3A5C);
const _primary      = Color(0xFFA78BFA);
// ─────────────────────────────────────────────────────

// FCM background handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.init();
  runApp(const TamStudioApp());
}

class TamStudioApp extends StatelessWidget {
  const TamStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tam Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF1A1A2E),
          primary: const Color(0xFFA78BFA),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        useMaterial3: true,
      ),
      home: const KeyGatePage(),
    );
  }
}

// ══════════════════════════════════════
//  Key Gate — enter user key on first launch
// ══════════════════════════════════════

class KeyGatePage extends StatefulWidget {
  const KeyGatePage({super.key});

  @override
  State<KeyGatePage> createState() => _KeyGatePageState();
}

class _KeyGatePageState extends State<KeyGatePage> {
  String? _savedKey;
  String _error = '';
  bool _signingIn = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '178808646003-tfd34jpt7ps4c6neaa0j22mrukdkjqb7.apps.googleusercontent.com',
    forceCodeForRefreshToken: true,
  );

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('app_version').get();
      if (!snapshot.exists) return;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final latest = data['latest'] as String? ?? '';
      final apkUrl = data['apk_url'] as String? ?? '';
      if (latest.isEmpty || apkUrl.isEmpty) return;
      if (latest != appVersion && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _UpdateDialog(newVersion: latest, apkUrl: apkUrl),
        );
      }
    } catch (_) {}
  }

  Future<void> _checkExistingAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Save UID locally for consistency
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/user_key.txt').writeAsString(user.uid);
      setState(() => _savedKey = user.uid);
      return;
    }

    // Fallback: check saved UID file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_key.txt');
      if (await file.exists()) {
        final key = await file.readAsString();
        if (key.trim().isNotEmpty) {
          // UID saved but not signed in — clear it, require re-sign-in
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _signingIn = true; _error = ''; });

    try {
      // Sign out first to always show account picker
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        setState(() { _signingIn = false; });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Save UID locally
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/user_key.txt').writeAsString(uid);
      setState(() { _savedKey = uid; _signingIn = false; });
    } catch (e) {
      setState(() {
        _signingIn = false;
        _error = '로그인 실패. 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_savedKey != null) {
      return HomePage(userKey: _savedKey!);
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: Text('🎮', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              const Text('Tam Studio', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Google 계정으로 로그인하세요', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(128))),
              const SizedBox(height: 32),
              if (_error.isNotEmpty) ...[
                Text(_error, style: const TextStyle(fontSize: 12, color: Color(0xFFF44336))),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _signingIn ? null : _signInWithGoogle,
                  icon: _signingIn
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login, color: Colors.white),
                  label: Text(
                    _signingIn ? '로그인 중...' : 'Google로 로그인',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String userKey;
  const HomePage({super.key, required this.userKey});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    NotificationService.instance.startListening(widget.userKey);
    NotificationService.instance.saveFcmToken(widget.userKey);
  }

  @override
  void dispose() {
    NotificationService.instance.stopListening();
    super.dispose();
  }

  void _onDisconnect() {
    // Navigate back to KeyGatePage
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KeyGatePage()),
      (_) => false,
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('app_version').get();
      if (!snapshot.exists) return;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final latest = data['latest'] as String? ?? '';
      final apkUrl = data['apk_url'] as String? ?? '';
      if (latest.isEmpty || apkUrl.isEmpty) return;
      if (latest != appVersion && mounted) {
        _showUpdateDialog(latest, apkUrl);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(String newVersion, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(newVersion: newVersion, apkUrl: apkUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        DatePage(userKey: widget.userKey),
        SettingsPage(userKey: widget.userKey, onDisconnect: _onDisconnect),
      ][_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: const Color(0xFF16162A),
        indicatorColor: const Color(0xFF2A2A4E),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '데이트'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Settings Page
// ══════════════════════════════════════

class SettingsPage extends StatefulWidget {
  final String userKey;
  final VoidCallback onDisconnect;
  const SettingsPage({super.key, required this.userKey, required this.onDisconnect});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final _calPlugin = DeviceCalendarPlugin();
  bool _calPermission = false;

  @override
  void initState() {
    super.initState();
    _checkCalPermission();
  }

  Future<void> _checkCalPermission() async {
    try {
      final result = await _calPlugin.hasPermissions();
      if (mounted) {
        setState(() => _calPermission = result.isSuccess && (result.data ?? false));
      }
    } catch (_) {}
  }

  Future<void> _requestCalPermission() async {
    try {
      final result = await _calPlugin.requestPermissions();
      if (mounted) {
        setState(() => _calPermission = result.isSuccess && (result.data ?? false));
      }
    } catch (_) {}
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22223A),
        title: const Text('연동 해제', style: TextStyle(color: Colors.white)),
        content: const Text('Google 계정 연동을 해제하면 다시 로그인해야 합니다.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF44336)),
            child: const Text('해제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_key.txt');
    if (await file.exists()) await file.delete();
    widget.onDisconnect();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFFA78BFA), size: 24),
                SizedBox(width: 8),
                Text('설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),

            // Google account info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22223A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333355)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF333355),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white54, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayName.isNotEmpty)
                          Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(153))),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('연동 중', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(179))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF555555)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('연동 해제 (로그아웃)', style: TextStyle(fontSize: 13, color: Color(0xFFEF5350))),
              ),
            ),
            const SizedBox(height: 12),

            // Calendar sync section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF22223A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333355)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: _textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('기기 캘린더 동기화',
                            style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          _calPermission ? '캘린더 일정을 표시합니다' : '권한이 없습니다',
                          style: TextStyle(fontSize: 11, color: _calPermission ? _success : _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_calPermission)
                    const Icon(Icons.check_circle_outline, color: _success, size: 20)
                  else
                    TextButton(
                      onPressed: _requestCalPermission,
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('권한 허용', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // App info
            Center(
              child: Column(
                children: [
                  Text('Tam Studio Mobile', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
                  const SizedBox(height: 4),
                  Text('v$appVersion', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(77))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Auto Update Dialog
// ══════════════════════════════════════

class _UpdateDialog extends StatefulWidget {
  final String newVersion;
  final String apkUrl;
  const _UpdateDialog({required this.newVersion, required this.apkUrl});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  static const _installChannel = MethodChannel('com.zziktam.tam_mobile_studio/installer');
  double _progress = 0;
  bool _downloading = false;
  String _status = '';

  Future<void> _downloadAndInstall() async {
    setState(() { _downloading = true; _status = '다운로드 중...'; });

    try {
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final filePath = '${dir.path}/tam-studio-update.apk';

      final oldFile = File(filePath);
      if (await oldFile.exists()) await oldFile.delete();

      await Dio().download(
        widget.apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _progress = received / total;
              _status = '${(received / 1024 / 1024).toStringAsFixed(1)} / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists() || await file.length() < 1000000) {
        setState(() { _downloading = false; _status = '다운로드 실패'; });
        return;
      }

      setState(() { _status = '설치 중...'; });

      // Call native Kotlin to install APK
      await _installChannel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      // Fallback: open in browser
      setState(() { _status = '브라우저로 이동...'; });
      try {
        await launchUrl(Uri.parse(widget.apkUrl), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF22223A),
      title: const Text('업데이트 알림', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('새 버전 ${widget.newVersion}\n현재 버전: $appVersion',
              style: TextStyle(color: Colors.white.withAlpha(200))),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress, color: const Color(0xFFA78BFA)),
            const SizedBox(height: 8),
            Text(_status, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('나중에', style: TextStyle(color: Colors.white.withAlpha(128))),
          ),
        if (!_downloading)
          ElevatedButton(
            onPressed: _downloadAndInstall,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA78BFA)),
            child: const Text('업데이트', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════
//  Notification Service
// ══════════════════════════════════════

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  StreamSubscription? _notifSubscription;

  Future<void> init() async {
    // Local notification setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'tam_studio_channel',
      'Tam Studio',
      description: 'Tam Studio 알림',
      importance: Importance.high,
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // FCM permission
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // FCM foreground handler → local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showLocal(notification.title ?? '', notification.body ?? '');
      }
    });
  }

  /// Start listening to Firebase notifications path for a user
  void startListening(String userKey) {
    _notifSubscription?.cancel();
    final ref = FirebaseDatabase.instance.ref('users/$userKey/notifications');
    _notifSubscription = ref.onChildAdded.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return;
      final title = data['title']?.toString() ?? '';
      final body = data['body']?.toString() ?? '';
      if (title.isNotEmpty || body.isNotEmpty) {
        showLocal(title, body);
      }
      // Mark as read
      event.snapshot.ref.update({'read': true});
    });
  }

  /// Save FCM token to Firebase for push notifications
  Future<void> saveFcmToken(String userKey) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseDatabase.instance.ref('users/$userKey/fcm_token').set(token);
      }
    } catch (_) {}
  }

  void showLocal(String title, String body) {
    _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tam_studio_channel',
          'Tam Studio',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  void stopListening() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
  }
}

// ══════════════════════════════════════
//  Date Feature — Models
// ══════════════════════════════════════

class DateEvent {
  final String id;
  final String title;
  final String date;       // "yyyy-MM-dd"
  final String time;       // "HH:mm" or ""
  final String location;
  final String category;
  final String memo;
  final List<String> tags;
  final String eventType;  // "normal" | "anniversary"
  final bool confirmed;
  final int createdAt;

  const DateEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.category,
    required this.memo,
    required this.tags,
    required this.eventType,
    required this.confirmed,
    required this.createdAt,
  });

  Color get barColor => eventType == 'anniversary' ? _accent : _primary;

  String get formattedDate {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return date;
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }

  factory DateEvent.fromMap(String id, Map<String, dynamic> m) {
    List<String> parseTags(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is Map) return raw.values.map((e) => e.toString()).toList();
      return [];
    }
    return DateEvent(
      id: id,
      title: m['title']?.toString() ?? '',
      date: m['date']?.toString() ?? '',
      time: m['time']?.toString() ?? '',
      location: m['location']?.toString() ?? '',
      category: m['category']?.toString() ?? '기타',
      memo: m['memo']?.toString() ?? '',
      tags: parseTags(m['tags']),
      eventType: m['eventType']?.toString() ?? 'normal',
      confirmed: m['confirmed'] as bool? ?? true,
      createdAt: m['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': date,
    'time': time,
    'location': location,
    'category': category,
    'memo': memo,
    'tags': tags,
    'eventType': eventType,
    'confirmed': confirmed,
    'createdAt': createdAt,
  };
}

class NativeCalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  const NativeCalendarEvent({required this.id, required this.title, required this.start});
}

class BucketItem {
  final String id;
  final String title;
  final String category;
  final int priority;      // 1=HIGH 2=MEDIUM 3=LOW
  final String memo;
  final List<String> tags;
  final bool done;
  final String doneAt;     // "yyyy-MM-dd" or ""
  final int createdAt;

  const BucketItem({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.memo,
    required this.tags,
    required this.done,
    required this.doneAt,
    required this.createdAt,
  });

  Color get priorityColor {
    switch (priority) {
      case 1: return _accent;
      case 2: return _primary;
      default: return _textSecondary;
    }
  }

  Color get barColor => done ? _success : _accent;

  String get priorityLabel {
    switch (priority) {
      case 1: return 'HIGH';
      case 2: return 'MED';
      default: return 'LOW';
    }
  }

  factory BucketItem.fromMap(String id, Map<String, dynamic> m) {
    List<String> parseTags(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is Map) return raw.values.map((e) => e.toString()).toList();
      return [];
    }
    return BucketItem(
      id: id,
      title: m['title']?.toString() ?? '',
      category: m['category']?.toString() ?? '기타',
      priority: m['priority'] as int? ?? 2,
      memo: m['memo']?.toString() ?? '',
      tags: parseTags(m['tags']),
      done: m['done'] as bool? ?? false,
      doneAt: m['doneAt']?.toString() ?? '',
      createdAt: m['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category,
    'priority': priority,
    'memo': memo,
    'tags': tags,
    'done': done,
    'doneAt': doneAt,
    'createdAt': createdAt,
  };
}

// ══════════════════════════════════════
//  Date Feature — EventCard + Animation
// ══════════════════════════════════════

class EventCard extends StatelessWidget {
  final Color barColor;
  final String title;
  final String subtitle;    // time + location
  final String tag;         // category or eventType badge
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.barColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: barColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: _textSecondary,
                          )),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tag,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: barColor,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideFadeItem extends StatefulWidget {
  final Widget child;
  final int index;
  const _SlideFadeItem({required this.child, required this.index});

  @override
  State<_SlideFadeItem> createState() => _SlideFadeItemState();
}

class _SlideFadeItemState extends State<_SlideFadeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final delay = widget.index * 60;
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ══════════════════════════════════════
//  Date Page
// ══════════════════════════════════════

class DatePage extends StatefulWidget {
  final String userKey;
  const DatePage({super.key, required this.userKey});

  @override
  State<DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<DatePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabCtrl;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<DateEvent>> _events = {};
  Map<DateTime, List<NativeCalendarEvent>> _nativeEvents = {};
  bool _calPermission = false;
  static final _calPlugin = DeviceCalendarPlugin();
  StreamSubscription? _sub;
  StreamSubscription? _widgetSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _subscribeEvents();
    _initWidgetClicked();
    _syncNativeCalendar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sub?.cancel();
    _widgetSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pushWidgetData();
      if (_calPermission) _syncNativeCalendar();
    }
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void _subscribeEvents() {
    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/dates');
    _sub = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        if (mounted) setState(() => _events = {});
        return;
      }
      final rawMap = Map<String, dynamic>.from(data as Map);
      final parsed = <DateTime, List<DateEvent>>{};
      rawMap.forEach((key, value) {
        final item = DateEvent.fromMap(key, Map<String, dynamic>.from(value as Map));
        final day = _normalizeDate(DateTime.parse(item.date));
        parsed.putIfAbsent(day, () => []).add(item);
      });
      if (mounted) {
        setState(() => _events = parsed);
        _pushWidgetData();
      }
    });
  }

  List<DateEvent> _eventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  Future<void> _pushWidgetData() async {
    try {
      final now = DateTime.now();
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      final monthStr = '${months[now.month - 1]} ${now.year}';

      // Find next upcoming event
      String preview = '일정 없음';
      final upcoming = _events.entries
          .where((e) => !e.key.isBefore(_normalizeDate(now)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      if (upcoming.isNotEmpty) {
        final next = upcoming.first.value.first;
        preview = '♥ 다음: ${next.title}${next.time.isNotEmpty ? " ${next.time}" : ""}';
      }

      // Serialize current month dates
      final thisMonthDates = _events.entries
          .where((e) => e.key.year == now.year && e.key.month == now.month)
          .map((e) => {
                'date': '${e.key.year}-${e.key.month.toString().padLeft(2,'0')}-${e.key.day.toString().padLeft(2,'0')}',
                'titles': e.value.map((ev) => ev.title).toList(),
              })
          .toList();

      await HomeWidget.saveWidgetData<String>('widgetMonth', monthStr);
      await HomeWidget.saveWidgetData<String>('widgetEventPreview', preview);
      await HomeWidget.saveWidgetData<String>('widgetDatesJson', jsonEncode(thisMonthDates));
      await HomeWidget.updateWidget(name: 'DateWidgetProvider', iOSName: 'DateWidget');
    } catch (e) {
      debugPrint('Widget sync failed: $e');
    }
  }

  Future<void> _initWidgetClicked() async {
    // Cold start: app launched via widget [+] button
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null && uri.host == 'add_event' && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddEvent());
    }
    // Hot start: app already running
    _widgetSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null && uri.host == 'add_event' && mounted) {
        _openAddEvent();
      }
    });
  }

  Future<void> _syncNativeCalendar([DateTime? month]) async {
    final target = month ?? _focusedDay;
    bool hasPermission = false;
    try {
      final hasResult = await _calPlugin.hasPermissions();
      hasPermission = hasResult.isSuccess && (hasResult.data ?? false);
      if (!hasPermission) {
        final reqResult = await _calPlugin.requestPermissions();
        hasPermission = reqResult.isSuccess && (reqResult.data ?? false);
      }
    } catch (_) {}
    if (!hasPermission) return;
    if (mounted && !_calPermission) setState(() => _calPermission = true);

    try {
      final calsResult = await _calPlugin.retrieveCalendars();
      if (!calsResult.isSuccess || calsResult.data == null) return;

      final start = tz.TZDateTime.utc(target.year, target.month, 1);
      final end = tz.TZDateTime.utc(target.year, target.month + 1, 1)
          .subtract(const Duration(seconds: 1));

      final newNative = <DateTime, List<NativeCalendarEvent>>{};
      for (final cal in calsResult.data!) {
        if (cal.id == null) continue;
        final evResult = await _calPlugin.retrieveEvents(
          cal.id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        if (!evResult.isSuccess || evResult.data == null) continue;
        for (final ev in evResult.data!) {
          if (ev.start == null) continue;
          final day = _normalizeDate(ev.start!.toLocal());
          if (day.year != target.year || day.month != target.month) continue;
          newNative.putIfAbsent(day, () => []).add(NativeCalendarEvent(
            id: ev.eventId ?? '',
            title: ev.title ?? '(제목 없음)',
            start: ev.start!.toLocal(),
          ));
        }
      }
      if (mounted) setState(() => _nativeEvents = newNative);
    } catch (e) {
      debugPrint('Native calendar sync failed: $e');
    }
  }

  void _openAddEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditEventSheet(userKey: widget.userKey, initialDate: _selectedDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Tab bar: [캘린더 | 버킷리스트]
          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: _primary,
              unselectedLabelColor: _textSecondary,
              indicatorColor: _primary,
              tabs: const [
                Tab(text: '캘린더'),
                Tab(text: '버킷리스트'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _CalendarTab(
                  selectedDay: _selectedDay,
                  focusedDay: _focusedDay,
                  events: _events,
                  eventsForDay: _eventsForDay,
                  onDaySelected: (sel, foc) {
                    setState(() { _selectedDay = sel; _focusedDay = foc; });
                  },
                  onFocusedDayChanged: (foc) {
                    setState(() => _focusedDay = foc);
                    if (_calPermission) _syncNativeCalendar(foc);
                  },
                  onAddEvent: _openAddEvent,
                  userKey: widget.userKey,
                  nativeEventsForDay: (day) =>
                      _nativeEvents[_normalizeDate(day)] ?? [],
                ),
                BucketlistPage(userKey: widget.userKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  final DateTime selectedDay;
  final DateTime focusedDay;
  final Map<DateTime, List<DateEvent>> events;
  final List<DateEvent> Function(DateTime) eventsForDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onFocusedDayChanged;
  final VoidCallback onAddEvent;
  final String userKey;
  final List<NativeCalendarEvent> Function(DateTime) nativeEventsForDay;

  const _CalendarTab({
    required this.selectedDay,
    required this.focusedDay,
    required this.events,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onFocusedDayChanged,
    required this.onAddEvent,
    required this.userKey,
    required this.nativeEventsForDay,
  });

  String _monthTitle(DateTime d) {
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = eventsForDay(selectedDay);
    final nativeEvents = nativeEventsForDay(selectedDay);
    return Column(
      children: [
        // Custom Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: _textSecondary),
                onPressed: () => onFocusedDayChanged(
                    DateTime(focusedDay.year, focusedDay.month - 1, 1)),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  _monthTitle(focusedDay),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: _textSecondary),
                onPressed: () => onFocusedDayChanged(
                    DateTime(focusedDay.year, focusedDay.month + 1, 1)),
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  onDaySelected(now, now);
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('오늘', style: TextStyle(fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _primary),
                onPressed: onAddEvent,
                tooltip: '이벤트 추가',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // TableCalendar
        TableCalendar<DateEvent>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, selectedDay),
          eventLoader: eventsForDay,
          onDaySelected: onDaySelected,
          onPageChanged: onFocusedDayChanged,
          calendarFormat: CalendarFormat.month,
          headerVisible: false,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            defaultTextStyle: GoogleFonts.nunito(color: _textPrimary),
            weekendTextStyle: GoogleFonts.nunito(color: _textPrimary),
            todayDecoration: BoxDecoration(
              border: Border.all(color: _primary, width: 1.5),
              shape: BoxShape.circle,
            ),
            todayTextStyle: GoogleFonts.nunito(color: _primary, fontWeight: FontWeight.bold),
            selectedDecoration: const BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
            markerDecoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            markerSize: 6,
            markersMaxCount: 3,
            cellMargin: const EdgeInsets.all(4),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: GoogleFonts.nunito(fontSize: 12, color: _textSecondary),
            weekendStyle: GoogleFonts.nunito(fontSize: 12, color: _textSecondary),
          ),
          rowHeight: 48,
        ),
        Divider(color: _dividerColor, height: 1),
        // Selected day label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${selectedDay.month}월 ${selectedDay.day}일',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (dayEvents.isNotEmpty || nativeEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${dayEvents.length + nativeEvents.length}',
                      style: GoogleFonts.nunito(fontSize: 11, color: _primary, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        // Event list
        Expanded(
          child: (dayEvents.isEmpty && nativeEvents.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_note_outlined, color: _textSecondary, size: 36),
                      const SizedBox(height: 8),
                      Text('이 날 일정이 없어요',
                          style: GoogleFonts.nunito(color: _textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: onAddEvent,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('추가하기', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: _primary),
                      ),
                    ],
                  ))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ...List.generate(dayEvents.length, (i) {
                      final ev = dayEvents[i];
                      final subtitle = [
                        if (ev.time.isNotEmpty) ev.time,
                        if (ev.location.isNotEmpty) ev.location,
                      ].join('  ·  ');
                      return Dismissible(
                        key: Key(ev.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withAlpha(200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          FirebaseDatabase.instance
                              .ref('users/$userKey/dates/${ev.id}')
                              .remove();
                        },
                        child: _SlideFadeItem(
                          index: i,
                          child: EventCard(
                            barColor: ev.barColor,
                            title: ev.title,
                            subtitle: subtitle,
                            tag: ev.category,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _EventDetailSheet(event: ev, userKey: userKey),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                    if (nativeEvents.isNotEmpty) ...[
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(child: Divider(color: _dividerColor, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('기기 캘린더',
                                  style: GoogleFonts.nunito(fontSize: 11, color: _textSecondary)),
                            ),
                            Expanded(child: Divider(color: _dividerColor, height: 1)),
                          ]),
                        ),
                      ...nativeEvents.map((nev) {
                        final timeStr = '${nev.start.hour.toString().padLeft(2,'0')}:${nev.start.minute.toString().padLeft(2,'0')}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _dividerColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: _textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(nev.title,
                                    style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: _textSecondary,
                                        fontStyle: FontStyle.italic)),
                              ),
                              if (nev.start.hour != 0 || nev.start.minute != 0)
                                Text(timeStr,
                                    style: GoogleFonts.nunito(fontSize: 11, color: _textSecondary)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════
//  Bucketlist Page
// ══════════════════════════════════════

class BucketlistPage extends StatefulWidget {
  final String userKey;
  const BucketlistPage({super.key, required this.userKey});

  @override
  State<BucketlistPage> createState() => _BucketlistPageState();
}

class _BucketlistPageState extends State<BucketlistPage> {
  List<BucketItem> _items = [];
  String _filter = '전체'; // '전체' | '미완료' | '완료'
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/bucketlist');
    _sub = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        if (mounted) setState(() => _items = []);
        return;
      }
      final rawMap = Map<String, dynamic>.from(data as Map);
      final parsed = rawMap.entries
          .map((e) => BucketItem.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)))
          .toList();
      parsed.sort((a, b) => a.priority.compareTo(b.priority));
      if (mounted) setState(() => _items = parsed);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<BucketItem> get _filtered {
    switch (_filter) {
      case '미완료': return _items.where((i) => !i.done).toList();
      case '완료':   return _items.where((i) => i.done).toList();
      default:       return _items;
    }
  }

  Future<void> _toggleDone(BucketItem item) async {
    final ref = FirebaseDatabase.instance
        .ref('users/${widget.userKey}/bucketlist/${item.id}');
    final now = DateTime.now();
    final doneAt = item.done
        ? ''
        : '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    await ref.update({'done': !item.done, 'doneAt': doneAt});
  }

  Future<void> _deleteItem(String id) async {
    await FirebaseDatabase.instance
        .ref('users/${widget.userKey}/bucketlist/$id')
        .remove();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = _items.length;
    final doneCount = _items.where((i) => i.done).length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text('Bucket List',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, color: _primary),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _AddEditBucketSheet(userKey: widget.userKey),
                  );
                },
              ),
            ],
          ),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    backgroundColor: _dividerColor,
                    valueColor: const AlwaysStoppedAnimation(_success),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('$doneCount / $total 완료',
                  style: GoogleFonts.nunito(fontSize: 11, color: _textSecondary)),
            ],
          ),
        ),
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['전체', '미완료', '완료'].map((f) {
              final sel = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: sel ? Colors.white : _textSecondary)),
                  selected: sel,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: _primary,
                  backgroundColor: _bgCard,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('버킷리스트가 비어있어요',
                      style: GoogleFonts.nunito(color: _textSecondary, fontSize: 13)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteItem(item.id),
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: ctx,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _BucketDetailSheet(
                                item: item, userKey: widget.userKey),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                                left: BorderSide(color: item.barColor, width: 4)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Done checkbox
                                GestureDetector(
                                  onTap: () => _toggleDone(item),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: item.done ? _success : Colors.transparent,
                                      border: Border.all(
                                          color:
                                              item.done ? _success : _textSecondary,
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: item.done
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: item.done
                                              ? _textSecondary
                                              : _textPrimary,
                                          decoration: item.done
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (item.category.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(item.category,
                                            style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                color: _textSecondary)),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.priorityColor.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item.priorityLabel,
                                      style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          color: item.priorityColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════
//  Event Detail Sheet
// ══════════════════════════════════════

class _EventDetailSheet extends StatelessWidget {
  final DateEvent event;
  final String userKey;
  const _EventDetailSheet({required this.event, required this.userKey});

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF22223A),
        title: const Text('삭제', style: TextStyle(color: Colors.white)),
        content: Text('"${event.title}" 을(를) 삭제할까요?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseDatabase.instance
        .ref('users/$userKey/dates/${event.id}')
        .remove();
    if (ctx.mounted) Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(event.formattedDate,
                style: GoogleFonts.nunito(fontSize: 13, color: _textSecondary)),
            const SizedBox(height: 6),
            Text(event.title,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 26, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 12),
            Divider(color: _dividerColor),
            if (event.time.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.access_time, text: event.time),
            ],
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.location_on_outlined, text: event.location),
            ],
            if (event.memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.notes_outlined, text: event.memo),
            ],
            if (event.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: event.tags
                    .map((t) => Chip(
                          label: Text(t,
                              style: GoogleFonts.nunito(
                                  fontSize: 11, color: _textSecondary)),
                          backgroundColor: _bgElevated,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: _dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AddEditEventSheet(
                            userKey: userKey, existing: event),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('수정하기',
                        style: GoogleFonts.nunito(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => _delete(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('삭제하기',
                        style: GoogleFonts.nunito(
                            color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.nunito(fontSize: 14, color: _textPrimary)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════
//  Add/Edit Event Sheet
// ══════════════════════════════════════

class _AddEditEventSheet extends StatefulWidget {
  final String userKey;
  final DateEvent? existing;
  final DateTime? initialDate;
  const _AddEditEventSheet({required this.userKey, this.existing, this.initialDate});

  @override
  State<_AddEditEventSheet> createState() => _AddEditEventSheetState();
}

class _AddEditEventSheetState extends State<_AddEditEventSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  late DateTime _date;
  String _time = '';
  String _category = '식사';
  String _eventType = 'normal';
  List<String> _tags = [];
  bool _saving = false;

  static const _categories = ['식사', '카페', '여행', '영화', '공연', '야외', '기념일', '기타'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _locationCtrl.text = e.location;
      _memoCtrl.text = e.memo;
      _date = DateTime.tryParse(e.date) ?? DateTime.now();
      _time = e.time;
      _category = e.category;
      _eventType = e.eventType;
      _tags = List.from(e.tags);
    } else {
      _date = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _memoCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final init = _time.isNotEmpty
        ? TimeOfDay(
            hour: int.tryParse(_time.split(':')[0]) ?? 12,
            minute: int.tryParse(_time.split(':')[1]) ?? 0)
        : const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/dates');
    final map = {
      'title': title,
      'date': _formatDate(_date),
      'time': _time,
      'location': _locationCtrl.text.trim(),
      'category': _category,
      'memo': _memoCtrl.text.trim(),
      'tags': _tags,
      'eventType': _eventType,
      'confirmed': true,
      'createdAt': widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    try {
      if (widget.existing != null) {
        await ref.child(widget.existing!.id).update(map);
      } else {
        await ref.push().set(map);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? '이벤트 수정' : '새 이벤트',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 20),
            // Title
            _SheetField(
              child: TextField(
                controller: _titleCtrl,
                style: GoogleFonts.nunito(fontSize: 15, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '이벤트 제목',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Date
            _SheetField(
              child: InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: _textSecondary),
                      const SizedBox(width: 10),
                      Text(_formatDate(_date),
                          style: GoogleFonts.nunito(fontSize: 14, color: _textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Time
            _SheetField(
              child: InkWell(
                onTap: _pickTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: _textSecondary),
                      const SizedBox(width: 10),
                      Text(_time.isEmpty ? '시간 (선택)' : _time,
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: _time.isEmpty ? _textSecondary : _textPrimary)),
                      if (_time.isNotEmpty) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _time = ''),
                          child: const Icon(Icons.close, size: 16, color: _textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Location
            _SheetField(
              child: TextField(
                controller: _locationCtrl,
                style: GoogleFonts.nunito(fontSize: 14, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '장소 (선택)',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Memo
            _SheetField(
              child: TextField(
                controller: _memoCtrl,
                style: GoogleFonts.nunito(fontSize: 14, color: _textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '메모 (선택)',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category
            Text('카테고리',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _primary : _bgElevated,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c,
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: sel ? Colors.white : _textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Event type
            Text('이벤트 유형',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'normal',
                    label: Text('일반', style: GoogleFonts.nunito(fontSize: 12))),
                ButtonSegment(
                    value: 'anniversary',
                    label: Text('기념일', style: GoogleFonts.nunito(fontSize: 12))),
              ],
              selected: {_eventType},
              onSelectionChanged: (s) => setState(() => _eventType = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: _bgElevated,
                foregroundColor: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Tags
            Text('태그',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetField(
                    child: TextField(
                      controller: _tagCtrl,
                      style: GoogleFonts.nunito(fontSize: 13, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: '태그 입력 후 Enter',
                        hintStyle: GoogleFonts.nunito(color: _textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (v) {
                        final t = v.trim();
                        if (t.isNotEmpty && !_tags.contains(t)) {
                          setState(() { _tags.add(t); _tagCtrl.clear(); });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _tags
                    .map((t) => Chip(
                          label: Text(t, style: GoogleFonts.nunito(fontSize: 11, color: _textPrimary)),
                          backgroundColor: _bgElevated,
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          deleteIconColor: _textSecondary,
                          onDeleted: () => setState(() => _tags.remove(t)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            // Save button
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('저장하기',
                        style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final Widget child;
  const _SheetField({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════
//  Bucket Detail Sheet
// ══════════════════════════════════════

class _BucketDetailSheet extends StatelessWidget {
  final BucketItem item;
  final String userKey;
  const _BucketDetailSheet({required this.item, required this.userKey});

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF22223A),
        title: const Text('삭제', style: TextStyle(color: Colors.white)),
        content: Text('"${item.title}" 을(를) 삭제할까요?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseDatabase.instance
        .ref('users/$userKey/bucketlist/${item.id}')
        .remove();
    if (ctx.mounted) Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 1.0,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.priorityColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.priorityLabel,
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: item.priorityColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.category,
                      style: GoogleFonts.nunito(fontSize: 11, color: _textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.title,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary)),
            if (item.done && item.doneAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('완료: ${item.doneAt}',
                  style: GoogleFonts.nunito(fontSize: 12, color: _success)),
            ],
            const SizedBox(height: 12),
            Divider(color: _dividerColor),
            if (item.memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.notes_outlined, text: item.memo),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.tags
                    .map((t) => Chip(
                          label: Text(t,
                              style: GoogleFonts.nunito(
                                  fontSize: 11, color: _textSecondary)),
                          backgroundColor: _bgElevated,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: _dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AddEditBucketSheet(
                            userKey: userKey, existing: item),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('수정하기',
                        style: GoogleFonts.nunito(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => _delete(context),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('삭제하기',
                        style: GoogleFonts.nunito(
                            color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Add/Edit Bucket Sheet
// ══════════════════════════════════════

class _AddEditBucketSheet extends StatefulWidget {
  final String userKey;
  final BucketItem? existing;
  const _AddEditBucketSheet({required this.userKey, this.existing});

  @override
  State<_AddEditBucketSheet> createState() => _AddEditBucketSheetState();
}

class _AddEditBucketSheetState extends State<_AddEditBucketSheet> {
  final _titleCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  String _category = '여행';
  int _priority = 2;
  List<String> _tags = [];
  bool _saving = false;

  static const _categories = ['식사', '카페', '여행', '영화', '공연', '야외', '기념일', '기타'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _memoCtrl.text = e.memo;
      _category = e.category;
      _priority = e.priority;
      _tags = List.from(e.tags);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/bucketlist');
    final map = {
      'title': title,
      'category': _category,
      'priority': _priority,
      'memo': _memoCtrl.text.trim(),
      'tags': _tags,
      'done': widget.existing?.done ?? false,
      'doneAt': widget.existing?.doneAt ?? '',
      'createdAt': widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    try {
      if (widget.existing != null) {
        await ref.child(widget.existing!.id).update(map);
      } else {
        await ref.push().set(map);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? '버킷 수정' : '버킷 추가',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 20),
            // Title
            _SheetField(
              child: TextField(
                controller: _titleCtrl,
                style: GoogleFonts.nunito(fontSize: 15, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '버킷 제목',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Memo
            _SheetField(
              child: TextField(
                controller: _memoCtrl,
                style: GoogleFonts.nunito(fontSize: 14, color: _textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '메모 (선택)',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category
            Text('카테고리',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _primary : _bgElevated,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c,
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: sel ? Colors.white : _textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Priority
            Text('우선순위',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text('HIGH', style: GoogleFonts.nunito(fontSize: 12))),
                ButtonSegment(value: 2, label: Text('MED', style: GoogleFonts.nunito(fontSize: 12))),
                ButtonSegment(value: 3, label: Text('LOW', style: GoogleFonts.nunito(fontSize: 12))),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: _bgElevated,
                foregroundColor: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Tags
            Text('태그',
                style: GoogleFonts.nunito(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _SheetField(
              child: TextField(
                controller: _tagCtrl,
                style: GoogleFonts.nunito(fontSize: 13, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '태그 입력 후 Enter',
                  hintStyle: GoogleFonts.nunito(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty && !_tags.contains(t)) {
                    setState(() { _tags.add(t); _tagCtrl.clear(); });
                  }
                },
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _tags
                    .map((t) => Chip(
                          label: Text(t, style: GoogleFonts.nunito(fontSize: 11, color: _textPrimary)),
                          backgroundColor: _bgElevated,
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          deleteIconColor: _textSecondary,
                          onDeleted: () => setState(() => _tags.remove(t)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('저장하기',
                        style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
