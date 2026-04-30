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
import 'package:home_widget/home_widget.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;

const String appVersion = '0.4.1';

// ── Date Feature Color Constants ──────────────────────
const _bgCard        = Color(0xFF362720);
const _bgElevated    = Color(0xFF422D25);
const _accent        = Color(0xFFF28C6B); // warm orange-salmon
const _success       = Color(0xFF6EE7B7); // mint
const _textPrimary   = Color(0xFFF5EBDD); // cream/ivory
const _textSecondary = Color(0xFFB9A79A); // warm mocha
const _dividerColor  = Color(0xFF43342E);
const _primary       = Color(0xFFF28C6B);
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
          surface: const Color(0xFF2B1F18),
          primary: const Color(0xFFF28C6B),
        ),
        scaffoldBackgroundColor: const Color(0xFF2B1F18),
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
                  color: const Color(0xFFF28C6B),
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
                    backgroundColor: const Color(0xFFF28C6B),
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
        backgroundColor: const Color(0xFF2B1F18),
        indicatorColor: _bgElevated,
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

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  static final _calPlugin = DeviceCalendarPlugin();
  bool _calPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCalPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkCalPermission();
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
        backgroundColor: _bgCard,
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
                Icon(Icons.settings, color: Color(0xFFF28C6B), size: 24),
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
                color: const Color(0xFF241D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF43342E)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF43342E),
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
                color: const Color(0xFF241D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF43342E)),
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
      backgroundColor: const Color(0xFF241D1A),
      title: const Text('업데이트 알림', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('새 버전 ${widget.newVersion}\n현재 버전: $appVersion',
              style: TextStyle(color: Colors.white.withAlpha(200))),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress, color: const Color(0xFFF28C6B)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF28C6B)),
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
  final String? endDate;   // "yyyy-MM-dd" or null (single-day)
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
    this.endDate,
    required this.time,
    required this.location,
    required this.category,
    required this.memo,
    required this.tags,
    required this.eventType,
    required this.confirmed,
    required this.createdAt,
  });

  DateTime get startDateTime => DateTime.parse(date);
  DateTime get endDateTime => endDate != null ? DateTime.parse(endDate!) : startDateTime;

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
      endDate: m['endDate']?.toString(),
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
    if (endDate != null) 'endDate': endDate!,
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
                        style: GoogleFonts.notoSansKr(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: GoogleFonts.notoSansKr(
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
                    style: GoogleFonts.notoSansKr(
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
  List<DateEvent> _allEvents = [];
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
        if (mounted) setState(() { _events = {}; _allEvents = []; });
        return;
      }
      final rawMap = Map<String, dynamic>.from(data as Map);
      final parsed = <DateTime, List<DateEvent>>{};
      final all = <DateEvent>[];
      rawMap.forEach((key, value) {
        final item = DateEvent.fromMap(key, Map<String, dynamic>.from(value as Map));
        all.add(item);
        final day = _normalizeDate(DateTime.parse(item.date));
        parsed.putIfAbsent(day, () => []).add(item);
      });
      if (mounted) {
        setState(() { _events = parsed; _allEvents = all; });
        _pushWidgetData();
      }
    });
  }

  List<DateEvent> _eventsForDay(DateTime day) {
    final normalized = _normalizeDate(day);
    return _allEvents.where((ev) {
      final start = _normalizeDate(ev.startDateTime);
      final end = _normalizeDate(ev.endDateTime);
      return !normalized.isBefore(start) && !normalized.isAfter(end);
    }).toList();
  }

  Future<void> _pushWidgetData([DateTime? focused]) async {
    try {
      final ref = focused ?? _focusedDay;
      final now = DateTime.now();
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      final monthStr = '${months[ref.month - 1]} ${ref.year}';

      // Upcoming events from _allEvents flat list, sorted by startDateTime
      final todayNorm = _normalizeDate(now);
      final upcoming = _allEvents
          .where((ev) => !_normalizeDate(ev.startDateTime).isBefore(todayNorm))
          .toList()
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      // Serialize upcoming event list (max 3) for widget event rows
      final eventsJsonList = upcoming.take(3).map((ev) {
        final d = ev.startDateTime;
        return {
          'date': '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}',
          'title': ev.title,
          'time': ev.time,
        };
      }).toList();

      // Serialize focused month dates (for calendar dot markers)
      final thisMonthDates = _allEvents
          .where((ev) {
            final s = ev.startDateTime;
            final e = ev.endDateTime;
            // Include if any part of the event overlaps the focused month
            return (s.year == ref.year && s.month == ref.month) ||
                   (e.year == ref.year && e.month == ref.month);
          })
          .map((ev) {
            final d = ev.startDateTime;
            return {
              'date': '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}',
              'titles': [ev.title],
            };
          })
          .toList();

      await HomeWidget.saveWidgetData<String>('widgetMonth', monthStr);
      await HomeWidget.saveWidgetData<String>('widgetEventsJson', jsonEncode(eventsJsonList));
      await HomeWidget.saveWidgetData<String>('widgetDatesJson', jsonEncode(thisMonthDates));
      await HomeWidget.updateWidget(name: 'DateWidgetProvider', iOSName: 'DateWidget');
    } catch (e) {
      debugPrint('Widget sync failed: $e');
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'add_event') {
      _openAddEvent();
    } else if (uri.host == 'open_date') {
      final dateStr = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          setState(() {
            _selectedDay = date;
            _focusedDay = date;
          });
        }
      }
    }
  }

  Future<void> _initWidgetClicked() async {
    // Cold start: app launched via widget tap
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleWidgetUri(uri));
    }
    // Hot start: app already running
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  // Direct MethodChannel bridge — bypasses device_calendar's Samsung-crashing projection
  static const _calChannel = MethodChannel('tam/native_calendar');

  Future<void> _syncNativeCalendar([DateTime? month]) async {
    final target = month ?? _focusedDay;

    // Permission check via device_calendar (stable — only crashes on retrieveCalendars/Events)
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

    // Use our own MethodChannel bridge (Samsung-safe projection, catch Throwable on native side)
    try {
      final startMs = DateTime(target.year, target.month, 1).millisecondsSinceEpoch;
      final endMs = DateTime(target.year, target.month + 1, 1)
          .subtract(const Duration(milliseconds: 1))
          .millisecondsSinceEpoch;

      final cals = await _calChannel.invokeListMethod<Map>('listCalendars') ?? [];
      final newNative = <DateTime, List<NativeCalendarEvent>>{};

      for (final cal in cals) {
        final calId = cal['id'] as String? ?? '';
        if (calId.isEmpty) continue;
        try {
          final evs = await _calChannel.invokeListMethod<Map>('listEvents', {
            'calendarId': calId,
            'startMs': startMs,
            'endMs': endMs,
          }) ?? [];
          for (final ev in evs) {
            final startEpoch = ev['startMs'] as int?;
            if (startEpoch == null) continue;
            final evStart = DateTime.fromMillisecondsSinceEpoch(startEpoch);
            final day = _normalizeDate(evStart);
            if (day.year != target.year || day.month != target.month) continue;
            newNative.putIfAbsent(day, () => []).add(NativeCalendarEvent(
              id: ev['id'] as String? ?? '',
              title: ev['title'] as String? ?? '(제목 없음)',
              start: evStart,
            ));
          }
        } catch (_) {
          continue; // skip this calendar on any error
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
            color: const Color(0xFF2B1F18),
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
                  allEvents: _allEvents,
                  eventsForDay: _eventsForDay,
                  onDaySelected: (sel, foc) {
                    setState(() { _selectedDay = sel; _focusedDay = foc; });
                  },
                  onFocusedDayChanged: (foc) {
                    setState(() => _focusedDay = foc);
                    if (_calPermission) _syncNativeCalendar(foc);
                    _pushWidgetData(foc);
                  },
                  onAddEvent: _openAddEvent,
                  userKey: widget.userKey,
                  nativeEventsForDay: (day) =>
                      _nativeEvents[_normalizeDate(day)] ?? [],
                  onEventTap: (ev) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _EventDetailSheet(event: ev, userKey: widget.userKey),
                    );
                  },
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

class _CalendarTab extends StatefulWidget {
  final DateTime selectedDay;
  final DateTime focusedDay;
  final List<DateEvent> allEvents;
  final List<DateEvent> Function(DateTime) eventsForDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onFocusedDayChanged;
  final VoidCallback onAddEvent;
  final String userKey;
  final List<NativeCalendarEvent> Function(DateTime) nativeEventsForDay;
  final void Function(DateEvent) onEventTap;

  const _CalendarTab({
    required this.selectedDay,
    required this.focusedDay,
    required this.allEvents,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onFocusedDayChanged,
    required this.onAddEvent,
    required this.userKey,
    required this.nativeEventsForDay,
    required this.onEventTap,
  });

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  int? _swipePointerId;
  double? _swipeStartDx;
  int? _swipeStartMs;

  String _monthTitle(DateTime d) {
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = widget.eventsForDay(widget.selectedDay)
      ..sort((a, b) {
        if (a.time.isEmpty && b.time.isEmpty) return 0;
        if (a.time.isEmpty) return -1;
        if (b.time.isEmpty) return 1;
        int toMin(String t) {
          final p = t.split(':');
          return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
        }
        return toMin(a.time).compareTo(toMin(b.time));
      });
    final nativeEvents = widget.nativeEventsForDay(widget.selectedDay);
    return Column(
      children: [
        // Custom Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: _textSecondary),
                onPressed: () => widget.onFocusedDayChanged(
                    DateTime(widget.focusedDay.year, widget.focusedDay.month - 1, 1)),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  _monthTitle(widget.focusedDay),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: _textSecondary),
                onPressed: () => widget.onFocusedDayChanged(
                    DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 1)),
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  widget.onDaySelected(now, now);
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
                onPressed: widget.onAddEvent,
                tooltip: '이벤트 추가',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // Galaxy-style calendar grid (swipe left/right — raw pointer, no gesture arena conflict)
        Listener(
          onPointerDown: (e) {
            if (_swipePointerId != null) return; // ignore secondary fingers
            _swipePointerId = e.pointer;
            _swipeStartDx = e.position.dx;
            _swipeStartMs = DateTime.now().millisecondsSinceEpoch;
          },
          onPointerUp: (e) {
            if (e.pointer != _swipePointerId) return;
            if (_swipeStartDx == null || _swipeStartMs == null) return;
            final dx = e.position.dx - _swipeStartDx!;
            final dt = DateTime.now().millisecondsSinceEpoch - _swipeStartMs!;
            _swipePointerId = null;
            _swipeStartDx = null;
            _swipeStartMs = null;
            if (dt == 0 || dx.abs() < 20) return; // ignore micro-movements
            final velocity = dx / dt * 1000;
            if (velocity < -300) {
              widget.onFocusedDayChanged(DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 1));
            } else if (velocity > 300) {
              widget.onFocusedDayChanged(DateTime(widget.focusedDay.year, widget.focusedDay.month - 1, 1));
            }
          },
          onPointerCancel: (e) {
            if (e.pointer != _swipePointerId) return;
            _swipePointerId = null;
            _swipeStartDx = null;
            _swipeStartMs = null;
          },
          child: _GalaxyCalendarGrid(
            focusedMonth: widget.focusedDay,
            selectedDay: widget.selectedDay,
            allEvents: widget.allEvents,
            nativeEventsForDay: widget.nativeEventsForDay,
            onDaySelected: widget.onDaySelected,
            onEventTap: widget.onEventTap,
          ),
        ),
        Divider(color: _dividerColor, height: 1),
        // Selected day label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${widget.selectedDay.month}월 ${widget.selectedDay.day}일',
                style: GoogleFonts.notoSansKr(
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
                      style: GoogleFonts.notoSansKr(fontSize: 11, color: _primary, fontWeight: FontWeight.bold)),
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
                          style: GoogleFonts.notoSansKr(color: _textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: widget.onAddEvent,
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
                        onDismissed: (_) async {
                          final snapshot = ev.toMap();
                          final evId = ev.id;
                          await FirebaseDatabase.instance
                              .ref('users/${widget.userKey}/dates/$evId')
                              .remove();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${ev.title}" 삭제됨'),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: '실행 취소',
                                onPressed: () {
                                  FirebaseDatabase.instance
                                      .ref('users/${widget.userKey}/dates/$evId')
                                      .set(snapshot);
                                },
                              ),
                            ),
                          );
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
                                builder: (_) => _EventDetailSheet(event: ev, userKey: widget.userKey),
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
                                  style: GoogleFonts.notoSansKr(fontSize: 11, color: _textSecondary)),
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
                                    style: GoogleFonts.notoSansKr(
                                        fontSize: 13,
                                        color: _textSecondary,
                                        fontStyle: FontStyle.italic)),
                              ),
                              if (nev.start.hour != 0 || nev.start.minute != 0)
                                Text(timeStr,
                                    style: GoogleFonts.notoSansKr(fontSize: 11, color: _textSecondary)),
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
//  Galaxy Calendar Grid
// ══════════════════════════════════════

const _kDayNumHeight = 28.0;
const _kBarHeight = 16.0;
const _kBarGap = 2.0;
const _kMaxLanes = 3;
const _kRowHeight = _kDayNumHeight + _kMaxLanes * (_kBarHeight + _kBarGap) + 6.0;

class _BarLayout {
  final String eventId;
  final String title;
  final Color color;
  final int startCol; // 0..6 within this week row
  final int endCol;   // inclusive
  final int lane;     // 0..2
  final bool isStart;
  final bool isEnd;
  final DateEvent? dateEvent; // null for native calendar events
  const _BarLayout({
    required this.eventId,
    required this.title,
    required this.color,
    required this.startCol,
    required this.endCol,
    required this.lane,
    required this.isStart,
    required this.isEnd,
    this.dateEvent,
  });
}

class _LayoutResult {
  final List<_BarLayout> bars;
  final Map<int, int> overflow; // col → hidden event count
  const _LayoutResult(this.bars, this.overflow);
}

class _GalaxyCalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<DateEvent> allEvents;
  final List<NativeCalendarEvent> Function(DateTime) nativeEventsForDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateEvent) onEventTap;

  const _GalaxyCalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.allEvents,
    required this.nativeEventsForDay,
    required this.onDaySelected,
    required this.onEventTap,
  });

  static DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  // Returns list of week rows: each row = list of 7 dates (leading/trailing months included)
  List<List<DateTime>> _buildWeeks() {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final offset = first.weekday % 7; // Sun=0,Mon=1..Sat=6
    final numRows = ((offset + daysInMonth) / 7).ceil();

    final weeks = <List<DateTime>>[];
    for (int row = 0; row < numRows; row++) {
      final week = <DateTime>[];
      for (int col = 0; col < 7; col++) {
        final idx = row * 7 + col;
        // DateTime handles day overflow/underflow into adjacent months
        week.add(DateTime(focusedMonth.year, focusedMonth.month, idx - offset + 1));
      }
      weeks.add(week);
    }
    return weeks;
  }

  // Compute bar layout + overflow for a week row
  _LayoutResult _layoutBars(List<DateTime> week, {int maxLanes = _kMaxLanes}) {
    final weekDates = week.map(_norm).toList();
    final weekStart = weekDates.first;
    final weekEnd = weekDates.last;

    final bars = <_BarLayout>[];
    final lanes = List<int>.filled(maxLanes, -1); // high-water endCol per lane
    final overflow = <int, int>{};

    // Firebase events — sorted by start, longer first
    final candidates = allEvents.where((ev) {
      final s = _norm(ev.startDateTime);
      final e = _norm(ev.endDateTime);
      return !e.isBefore(weekStart) && !s.isAfter(weekEnd);
    }).toList()
      ..sort((a, b) {
        final as_ = _norm(a.startDateTime);
        final bs = _norm(b.startDateTime);
        if (as_ != bs) return as_.compareTo(bs);
        final ae = _norm(a.endDateTime);
        final be = _norm(b.endDateTime);
        return be.difference(bs).compareTo(ae.difference(as_)); // longer first
      });

    for (final ev in candidates) {
      final evStart = _norm(ev.startDateTime);
      final evEnd = _norm(ev.endDateTime);

      int startCol = 0, endCol = 6;
      for (int c = 0; c < 7; c++) {
        if (!weekDates[c].isBefore(evStart)) { startCol = c; break; }
      }
      for (int c = 6; c >= 0; c--) {
        if (!weekDates[c].isAfter(evEnd)) { endCol = c; break; }
      }

      int lane = -1;
      for (int l = 0; l < maxLanes; l++) {
        if (lanes[l] < startCol) { lane = l; break; }
      }
      if (lane == -1) {
        for (int c = startCol; c <= endCol; c++) {
          overflow[c] = (overflow[c] ?? 0) + 1;
        }
        continue;
      }
      lanes[lane] = endCol;

      bars.add(_BarLayout(
        eventId: ev.id,
        title: ev.title,
        color: ev.barColor,
        startCol: startCol,
        endCol: endCol,
        lane: lane,
        isStart: !evStart.isBefore(weekDates[startCol]),
        isEnd: !evEnd.isAfter(weekDates[endCol]),
        dateEvent: ev,
      ));
    }

    // Native calendar events — single-day, fill remaining lane slots
    for (int col = 0; col < 7; col++) {
      final natives = nativeEventsForDay(weekDates[col]);
      for (final nev in natives) {
        final occupiedLanes = bars
            .where((b) => b.startCol <= col && b.endCol >= col)
            .map((b) => b.lane)
            .toSet();
        int lane = -1;
        for (int l = 0; l < maxLanes; l++) {
          if (!occupiedLanes.contains(l)) { lane = l; break; }
        }
        if (lane == -1) {
          overflow[col] = (overflow[col] ?? 0) + 1;
          continue;
        }
        bars.add(_BarLayout(
          eventId: 'native_${col}_${nev.id}',
          title: nev.title,
          color: _textSecondary,
          startCol: col,
          endCol: col,
          lane: lane,
          isStart: true,
          isEnd: true,
          dateEvent: null,
        ));
      }
    }

    return _LayoutResult(bars, overflow);
  }

  Widget _buildWeekRow(BuildContext context, List<DateTime> week, _LayoutResult layout, {double rowHeight = _kRowHeight}) {
    return SizedBox(
      height: rowHeight,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final cellW = constraints.maxWidth / 7;
        final selCol = week.indexWhere(
            (d) => _norm(d) == _norm(selectedDay));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Selected column highlight
            if (selCol >= 0 && week[selCol].month == focusedMonth.month)
              Positioned(
                left: selCol * cellW,
                top: 0,
                width: cellW,
                height: rowHeight,
                child: Container(color: _primary.withAlpha(18)),
              ),
            // Day number cells
            Row(
              children: List.generate(7, (col) {
                final day = week[col];
                final isCurrentMonth = day.month == focusedMonth.month;
                final isToday = _norm(day) == _norm(DateTime.now());
                final isSel = col == selCol && isCurrentMonth;
                Color textColor = isCurrentMonth ? _textPrimary : _textSecondary.withAlpha(100);
                if (isCurrentMonth && col == 0) textColor = _accent;
                if (isCurrentMonth && col == 6) textColor = _primary;

                return Semantics(
                  label: '${day.year}년 ${day.month}월 ${day.day}일',
                  button: true,
                  child: GestureDetector(
                    onTap: () => onDaySelected(day, day),
                    child: SizedBox(
                      width: cellW,
                      height: rowHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 22, height: 22,
                            alignment: Alignment.center,
                            decoration: isSel
                                ? const BoxDecoration(color: _primary, shape: BoxShape.circle)
                                : isToday
                                    ? BoxDecoration(
                                        border: Border.all(color: _primary, width: 1.5),
                                        shape: BoxShape.circle)
                                    : null,
                            child: Text(
                              '${day.day}',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : isToday ? _primary : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Event bars
            ...layout.bars.map((bar) {
              final left = bar.startCol * cellW + 1;
              final width = (bar.endCol - bar.startCol + 1) * cellW - 2;
              final top = _kDayNumHeight + bar.lane * (_kBarHeight + _kBarGap);
              return Positioned(
                left: left,
                top: top,
                width: width,
                height: _kBarHeight,
                child: GestureDetector(
                  onTap: () {
                    if (bar.dateEvent != null) {
                      onEventTap(bar.dateEvent!);
                    } else {
                      onDaySelected(week[bar.startCol], week[bar.startCol]);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bar.color.withAlpha(220),
                      borderRadius: BorderRadius.horizontal(
                        left: bar.isStart ? const Radius.circular(4) : Radius.zero,
                        right: bar.isEnd ? const Radius.circular(4) : Radius.zero,
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: bar.isStart
                        ? Text(
                            bar.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              );
            }),
            // +N overflow indicators
            ...layout.overflow.entries.map((entry) {
              final col = entry.key;
              final count = entry.value;
              return Positioned(
                left: col * cellW,
                bottom: 2,
                width: cellW,
                child: Text(
                  '+$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildWeeks();

    return Column(
      children: [
        // Day-of-week header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: Row(
            children: ['일','월','화','수','목','금','토'].map((label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 11,
                  color: label == '일'
                      ? _accent
                      : label == '토'
                          ? _primary
                          : _textSecondary,
                ),
              ),
            )).toList(),
          ),
        ),
        const Divider(color: _dividerColor, height: 1),
        // Week rows
        ...() {
          final is6Row = weeks.length > 5;
          final effectiveMaxLanes = is6Row ? 2 : _kMaxLanes;
          final effectiveRowH = _kDayNumHeight + effectiveMaxLanes * (_kBarHeight + _kBarGap) + 6.0;
          return weeks.map((week) {
            final layout = _layoutBars(week, maxLanes: effectiveMaxLanes);
            return Column(
              children: [
                _buildWeekRow(context, week, layout, rowHeight: effectiveRowH),
                const Divider(color: _dividerColor, height: 1, thickness: 0.5),
              ],
            );
          });
        }(),
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
                  style: GoogleFonts.notoSansKr(
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
                  style: GoogleFonts.notoSansKr(fontSize: 11, color: _textSecondary)),
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
                      style: GoogleFonts.notoSansKr(
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
                      style: GoogleFonts.notoSansKr(color: _textSecondary, fontSize: 13)))
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
                      onDismissed: (_) async {
                          final snapshot = item.toMap();
                          final itemId = item.id;
                          await _deleteItem(itemId);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('"${item.title}" 삭제됨'),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: '실행 취소',
                                onPressed: () {
                                  FirebaseDatabase.instance
                                      .ref('users/${widget.userKey}/bucketlist/$itemId')
                                      .set(snapshot);
                                },
                              ),
                            ),
                          );
                        },
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
                                        style: GoogleFonts.notoSansKr(
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
                                            style: GoogleFonts.notoSansKr(
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
                                      style: GoogleFonts.notoSansKr(
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

  static String _formatDateStr(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const months = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _bgCard,
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
            Row(
              children: [
                Text(
                  event.endDate != null
                      ? '${event.formattedDate}  ~  ${_formatDateStr(event.endDate!)}'
                      : event.formattedDate,
                  style: GoogleFonts.notoSansKr(fontSize: 13, color: _textSecondary),
                ),
                const Spacer(),
                if (event.eventType == 'anniversary')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('기념일',
                        style: GoogleFonts.notoSansKr(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(event.title,
                style: GoogleFonts.notoSansKr(
                    fontSize: 26, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primary.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(event.category,
                  style: GoogleFonts.notoSansKr(fontSize: 11, color: _primary, fontWeight: FontWeight.w600)),
            ),
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
                              style: GoogleFonts.notoSansKr(
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
                        style: GoogleFonts.notoSansKr(color: _primary, fontWeight: FontWeight.bold)),
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
                        style: GoogleFonts.notoSansKr(
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
              style: GoogleFonts.notoSansKr(fontSize: 14, color: _textPrimary)),
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
  DateTime? _endDate;
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
      _endDate = e.endDate != null ? DateTime.tryParse(e.endDate!) : null;
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
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _date,
      firstDate: _date,
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
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
    final map = <String, dynamic>{
      'title': title,
      'date': _formatDate(_date),
      if (_endDate != null && !_endDate!.isBefore(_date)) 'endDate': _formatDate(_endDate!),
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
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
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
                style: GoogleFonts.notoSansKr(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 20),
            // Title
            _SheetField(
              child: TextField(
                controller: _titleCtrl,
                style: GoogleFonts.notoSansKr(fontSize: 15, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '이벤트 제목',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Date (start)
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
                          style: GoogleFonts.notoSansKr(fontSize: 14, color: _textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // End date (optional, for multi-day events)
            _SheetField(
              child: InkWell(
                onTap: _pickEndDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 18,
                          color: _endDate != null ? _primary : _textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _endDate != null ? '~ ${_formatDate(_endDate!)}' : '종료일 (선택, 1박2일 등)',
                        style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            color: _endDate != null ? _textPrimary : _textSecondary),
                      ),
                      if (_endDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _endDate = null),
                          child: const Icon(Icons.close, size: 16, color: _textSecondary),
                        ),
                      ],
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
                          style: GoogleFonts.notoSansKr(
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
                style: GoogleFonts.notoSansKr(fontSize: 14, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '장소 (선택)',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
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
                style: GoogleFonts.notoSansKr(fontSize: 14, color: _textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '메모 (선택)',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category
            Text('카테고리',
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
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
                        style: GoogleFonts.notoSansKr(
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
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'normal',
                    label: Text('일반', style: GoogleFonts.notoSansKr(fontSize: 12))),
                ButtonSegment(
                    value: 'anniversary',
                    label: Text('기념일', style: GoogleFonts.notoSansKr(fontSize: 12))),
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
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetField(
                    child: TextField(
                      controller: _tagCtrl,
                      style: GoogleFonts.notoSansKr(fontSize: 13, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: '태그 입력 후 Enter',
                        hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
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
                          label: Text(t, style: GoogleFonts.notoSansKr(fontSize: 11, color: _textPrimary)),
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
                        style: GoogleFonts.notoSansKr(
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
        backgroundColor: _bgCard,
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
                      style: GoogleFonts.notoSansKr(
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
                      style: GoogleFonts.notoSansKr(fontSize: 11, color: _textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.title,
                style: GoogleFonts.notoSansKr(
                    fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary)),
            if (item.done && item.doneAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('완료: ${item.doneAt}',
                  style: GoogleFonts.notoSansKr(fontSize: 12, color: _success)),
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
                              style: GoogleFonts.notoSansKr(
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
                        style: GoogleFonts.notoSansKr(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => _delete(context),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('삭제하기',
                        style: GoogleFonts.notoSansKr(
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
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
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
                style: GoogleFonts.notoSansKr(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 20),
            // Title
            _SheetField(
              child: TextField(
                controller: _titleCtrl,
                style: GoogleFonts.notoSansKr(fontSize: 15, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '버킷 제목',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
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
                style: GoogleFonts.notoSansKr(fontSize: 14, color: _textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '메모 (선택)',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category
            Text('카테고리',
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
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
                        style: GoogleFonts.notoSansKr(
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
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text('HIGH', style: GoogleFonts.notoSansKr(fontSize: 12))),
                ButtonSegment(value: 2, label: Text('MED', style: GoogleFonts.notoSansKr(fontSize: 12))),
                ButtonSegment(value: 3, label: Text('LOW', style: GoogleFonts.notoSansKr(fontSize: 12))),
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
                style: GoogleFonts.notoSansKr(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _SheetField(
              child: TextField(
                controller: _tagCtrl,
                style: GoogleFonts.notoSansKr(fontSize: 13, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: '태그 입력 후 Enter',
                  hintStyle: GoogleFonts.notoSansKr(color: _textSecondary),
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
                          label: Text(t, style: GoogleFonts.notoSansKr(fontSize: 11, color: _textPrimary)),
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
                        style: GoogleFonts.notoSansKr(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
