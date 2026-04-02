import 'dart:async';
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

const String appVersion = '0.0.9';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
//  Chat Send Page
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
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance
        .ref('users/${widget.userKey}/chat_history')
        .orderByChild('timestamp')
        .limitToLast(50);
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) {
        setState(() => _messages = []);
        return;
      }
      List<Map<String, dynamic>> parsed = [];
      if (data is Map) {
        data.forEach((key, value) {
          if (value != null) {
            final msg = Map<String, dynamic>.from(value as Map);
            msg['_key'] = key;
            parsed.add(msg);
          }
        });
      }
      parsed.sort((a, b) =>
          (a['timestamp'] as num? ?? 0).compareTo(b['timestamp'] as num? ?? 0));
      setState(() => _messages = parsed);
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

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userRef = FirebaseDatabase.instance.ref('users/${widget.userKey}');

      // Write to chat_send for PC to pick up
      await userRef.child('chat_send').set({
        'text': text,
        'timestamp': timestamp,
      });

      // Append to chat_history for display
      await userRef.child('chat_history').push().set({
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Color(0xFFA78BFA), size: 24),
                const SizedBox(width: 8),
                const Text('채팅 전송',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Spacer(),
                Text('${_messages.length}개',
                    style:
                        TextStyle(fontSize: 12, color: Colors.white.withAlpha(128))),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('메시지 없음\n아래에서 채팅을 입력하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withAlpha(77))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                  ),
          ),
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
                      hintText: '메시지를 입력하세요...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                      filled: true,
                      fillColor: const Color(0xFF22223A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFA78BFA)))
                      : const Icon(Icons.arrow_upward,
                          color: Color(0xFFA78BFA)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF22223A),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final text = msg['text'] ?? '';
    final status = msg['status'] ?? 'pending';
    final statusText = status == 'sent' ? '전송됨' : '전송 중...';
    final statusColor =
        status == 'sent' ? const Color(0xFF4CAF50) : Colors.white.withAlpha(102);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 60),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A4E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFF3A3A5E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text,
                style: const TextStyle(fontSize: 14, color: Colors.white)),
            const SizedBox(height: 4),
            Text(statusText,
                style: TextStyle(fontSize: 10, color: statusColor)),
          ],
        ),
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
