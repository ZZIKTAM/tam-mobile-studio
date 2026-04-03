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

const String appVersion = '0.1.5';

// FCM background handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.init();
  await AssetService.instance.init();
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
        BuffMonitorPage(userKey: widget.userKey),
        DropTrackerPage(userKey: widget.userKey),
        ChatSendPage(userKey: widget.userKey),
        SettingsPage(userKey: widget.userKey, onDisconnect: _onDisconnect),
      ][_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: const Color(0xFF16162A),
        indicatorColor: const Color(0xFF2A2A4E),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield), label: '버프'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: '드랍'),
          NavigationDestination(icon: Icon(Icons.chat), label: '채팅'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Buff Monitor Page
// ══════════════════════════════════════

class BuffMonitorPage extends StatefulWidget {
  final String userKey;
  const BuffMonitorPage({super.key, required this.userKey});

  @override
  State<BuffMonitorPage> createState() => _BuffMonitorPageState();
}

class _BuffMonitorPageState extends State<BuffMonitorPage> {
  List<Map<String, dynamic>> _buffs = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/buffs');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        setState(() => _buffs = []);
        return;
      }
      List<Map<String, dynamic>> parsed = [];
      if (data is List) {
        parsed = data.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (data is Map) {
        parsed = data.values.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      setState(() => _buffs = parsed);
    });

    // Refresh UI every 100ms for smooth countdown timers
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_buffs.isNotEmpty && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFFA78BFA), size: 24),
                const SizedBox(width: 8),
                const Text('버프 모니터',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Text('${_buffs.length}개 활성',
                    style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
              ],
            ),
          ),
          Expanded(
            child: _buffs.isEmpty
                ? Center(
                    child: Text('활성 버프 없음\nPC에서 캡처 시작 후 게임 접속하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withAlpha(77))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _buffs.length,
                    itemBuilder: (ctx, i) => _buildBuffCard(_buffs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuffCard(Map<String, dynamic> buff) {
    final name = buff['name'] ?? '?';
    final duration = (buff['duration'] ?? 0) as num;
    final start = (buff['start'] ?? 0) as num;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - start.toInt();
    final remaining = duration > 0 ? (duration.toInt() - elapsed) : -1;
    final progress = duration > 0 ? (remaining / duration).clamp(0.0, 1.0) : 1.0;
    final barColor = progress > 0.3
        ? const Color(0xFF4CAF50)
        : progress > 0.1
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);

    String timeText;
    if (remaining < 0) {
      timeText = '∞';
    } else if (remaining > 60000) {
      timeText = '${(remaining / 60000).floor()}:${((remaining % 60000) / 1000).floor().toString().padLeft(2, '0')}';
    } else {
      timeText = '${(remaining / 1000).toStringAsFixed(1)}s';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF22223A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333355)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                Text(timeText,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: barColor)),
              ],
            ),
          ),
          if (duration > 0)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: barColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Drop Tracker Page
// ══════════════════════════════════════

class DropTrackerPage extends StatefulWidget {
  final String userKey;
  const DropTrackerPage({super.key, required this.userKey});

  @override
  State<DropTrackerPage> createState() => _DropTrackerPageState();
}

class _DropTrackerPageState extends State<DropTrackerPage> {
  bool _measuring = false;
  double _elapsed = 0;
  double _lastServerElapsed = 0;
  DateTime _lastServerTime = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Refresh elapsed time locally every second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_measuring && mounted) {
        setState(() {
          _elapsed = _lastServerElapsed + DateTime.now().difference(_lastServerTime).inMilliseconds / 1000.0;
        });
      }
    });

    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/drops');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;
      if (data is Map) {
        setState(() {
          _measuring = data['measuring'] == true;
          _lastServerElapsed = (data['elapsed'] ?? 0).toDouble();
          _lastServerTime = DateTime.now();
          _elapsed = _lastServerElapsed;
          final rawItems = data['items'];
          if (rawItems is List) {
            _items = rawItems.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          } else if (rawItems is Map) {
            _items = rawItems.values.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(double seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    final s = (seconds % 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Color(0xFFA78BFA), size: 24),
                const SizedBox(width: 8),
                const Text('드랍 측정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _measuring ? const Color(0xFF1B5E20) : const Color(0xFF333355),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _measuring ? '측정 중' : '대기',
                    style: TextStyle(
                        fontSize: 11,
                        color: _measuring ? const Color(0xFF81C784) : Colors.white.withAlpha(128)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('경과: ${_formatElapsed(_elapsed)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Text('${_items.length}종',
                    style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text('드랍 데이터 없음\nPC에서 드랍 측정 시작하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withAlpha(77))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _buildDropItem(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropItem(Map<String, dynamic> item) {
    final name = item['name'] ?? '?';
    final amount = item['amount'] ?? 0;
    final itemId = item['id']?.toString() ?? '';
    final iconBasename = AssetService.instance.itemIconMap[itemId];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22223A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333355)),
      ),
      child: Row(
        children: [
          if (iconBasename != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset(
                'assets/icons/$iconBasename.webp',
                width: 36, height: 36,
                errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36),
              ),
            )
          else
            const SizedBox(width: 44),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
          Text('×$amount',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFA78BFA))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Chat Page (receive game chat + send)
// ══════════════════════════════════════

class ChatSendPage extends StatefulWidget {
  final String userKey;
  const ChatSendPage({super.key, required this.userKey});

  @override
  State<ChatSendPage> createState() => _ChatSendPageState();
}

class _ChatSendPageState extends State<ChatSendPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _chatMessages = [];
  String _filterChannel = 'ALL';
  bool _sending = false;

  static const Map<String, Color> channelColors = {
    '월드': Color(0xFFE88BA7),
    '로컬': Color(0xFF8892A8),
    '파티': Color(0xFF5EAEFF),
    '길드': Color(0xFF7DD3A0),
    '귓속말': Color(0xFFC084FC),
    '시스템': Color(0xFFA78BFA),
    '그룹': Color(0xFFF59E0B),
    '공지': Color(0xFFEF4444),
  };

  @override
  void initState() {
    super.initState();
    // Subscribe to game chat from PC
    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/chat');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        setState(() => _chatMessages = []);
        return;
      }
      List<Map<String, dynamic>> parsed = [];
      if (data is List) {
        parsed = data.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (data is Map) {
        parsed = data.values.where((e) => e != null).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      parsed.sort((a, b) => (a['ts'] as num? ?? 0).compareTo(b['ts'] as num? ?? 0));
      setState(() => _chatMessages = parsed);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> get _filteredMessages {
    if (_filterChannel == 'ALL') return _chatMessages;
    return _chatMessages.where((m) => m['ch'] == _filterChannel).toList();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userRef = FirebaseDatabase.instance.ref('users/${widget.userKey}');
      final historyRef = userRef.child('chat_history').push();
      final historyKey = historyRef.key ?? '';

      await userRef.child('chat_send').set({
        'text': text,
        'timestamp': timestamp,
        'historyKey': historyKey,
      });
      await historyRef.set({
        'text': text,
        'timestamp': timestamp,
        'status': 'pending',
      });
    } catch (_) {}

    setState(() => _sending = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMessages;
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Color(0xFFA78BFA), size: 24),
                const SizedBox(width: 8),
                const Text('채팅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Text('${filtered.length}개', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
              ],
            ),
          ),
          // Channel filter
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['ALL', '월드', '파티', '길드', '귓속말', '시스템'].map((ch) {
                final selected = _filterChannel == ch;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(ch, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white.withAlpha(153))),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterChannel = ch),
                    selectedColor: const Color(0xFFA78BFA),
                    backgroundColor: const Color(0xFF22223A),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Chat messages
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('채팅 없음\nPC에서 게임 접속 후 채팅이 표시됩니다',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(77))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildChatBubble(filtered[i]),
                  ),
          ),
          // Send input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16162A),
              border: Border(top: BorderSide(color: Color(0xFF333355))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '게임 채팅 전송...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                      filled: true, fillColor: const Color(0xFF22223A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA78BFA)))
                      : const Icon(Icons.arrow_upward, color: Color(0xFFA78BFA)),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF22223A), shape: const CircleBorder()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final ch = msg['ch'] ?? '기타';
    final nick = msg['nick'] ?? '';
    final text = msg['msg'] ?? '';
    final type = msg['type'] ?? 0;
    final color = channelColors[ch] ?? const Color(0xFF8892A8);

    String? stickerFile;
    String displayMsg = text;
    if (type == 3) {
      final emote = msg['emote'];
      if (emote != null) {
        final stickerInfo = AssetService.instance.stickerMap[emote.toString()];
        stickerFile = stickerInfo?['file'] as String?;
      }
      if (stickerFile == null) displayMsg = '[이모티콘]';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22223A),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[$ch] ', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          if (nick.isNotEmpty) Text('$nick: ', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          if (stickerFile != null)
            Image.asset('assets/emojis/$stickerFile.webp', width: 48, height: 48,
                errorBuilder: (_, __, ___) => const Text('[이모티콘]', style: TextStyle(fontSize: 12, color: Colors.white70)))
          else
            Expanded(child: Text(displayMsg, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(230)))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Settings Page
// ══════════════════════════════════════

class SettingsPage extends StatelessWidget {
  final String userKey;
  final VoidCallback onDisconnect;
  const SettingsPage({super.key, required this.userKey, required this.onDisconnect});

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

    // Sign out from Google and Firebase
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Delete saved UID
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_key.txt');
    if (await file.exists()) await file.delete();
    onDisconnect();
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
//  Asset Service
// ══════════════════════════════════════

class AssetService {
  static final AssetService instance = AssetService._();
  AssetService._();

  // item_id (string) -> icon_basename (without extension)
  Map<String, String> itemIconMap = {};
  // config_id (string) -> sticker info map
  Map<String, Map<String, dynamic>> stickerMap = {};

  Future<void> init() async {
    try {
      final iconJson = await rootBundle.loadString('assets/item_icons.json');
      final raw = jsonDecode(iconJson) as Map<String, dynamic>;
      itemIconMap = raw.map((k, v) => MapEntry(k, v as String));
    } catch (_) {}

    try {
      final stickerJson = await rootBundle.loadString('assets/chat_stickers.json');
      final raw = jsonDecode(stickerJson) as Map<String, dynamic>;
      stickerMap = raw.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {}
  }
}
