import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

const String appVersion = '0.1.4';

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
  final _controller = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    // Simple local storage via Firebase — check if key was saved before
    // Using a local file for persistence
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_key.txt');
      if (await file.exists()) {
        final key = await file.readAsString();
        if (key.trim().isNotEmpty) {
          setState(() => _savedKey = key.trim());
        }
      }
    } catch (_) {}
  }

  Future<void> _saveAndConnect() async {
    final key = _controller.text.trim().toUpperCase();
    if (key.length < 4) {
      setState(() => _error = '키를 입력하세요');
      return;
    }

    // Verify key exists in Firebase
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users/$key').get();
      if (!snapshot.exists) {
        setState(() => _error = '유효하지 않은 키입니다. PC 앱에서 확인하세요.');
        return;
      }
    } catch (e) {
      // If can't verify, still save (might not have data yet)
    }

    // Save locally
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/user_key.txt').writeAsString(key);
    setState(() => _savedKey = key);
  }

  void _disconnect() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_key.txt');
    if (await file.exists()) await file.delete();
    setState(() { _savedKey = null; _controller.clear(); _error = ''; });
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
              Text('PC 앱에 표시된 연동 키를 입력하세요', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(128))),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')), LengthLimitingTextInputFormatter(6)],
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(51), letterSpacing: 8),
                  filled: true,
                  fillColor: const Color(0xFF22223A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333355))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333355))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFA78BFA))),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(fontSize: 12, color: Color(0xFFF44336))),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saveAndConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('연동하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      if (data is List) {
        setState(() {
          _buffs = data
              .where((e) => e != null)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    });
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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/drops');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;
      if (data is Map) {
        setState(() {
          _measuring = data['measuring'] == true;
          _elapsed = (data['elapsed'] ?? 0).toDouble();
          final rawItems = data['items'];
          if (rawItems is List) {
            _items = rawItems
                .where((e) => e != null)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        });
      }
    });
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
//  Settings Page
// ══════════════════════════════════════

class SettingsPage extends StatelessWidget {
  final String userKey;
  final VoidCallback onDisconnect;
  const SettingsPage({super.key, required this.userKey, required this.onDisconnect});

  Future<void> _disconnectKey(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22223A),
        title: const Text('연동 해제', style: TextStyle(color: Colors.white)),
        content: const Text('연동을 해제하면 새 키를 입력해야 합니다.', style: TextStyle(color: Colors.white70)),
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

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_key.txt');
    if (await file.exists()) await file.delete();
    onDisconnect();
  }

  @override
  Widget build(BuildContext context) {
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

            // Connection info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22223A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333355)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('연동 키', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(128))),
                  const SizedBox(height: 8),
                  Text(userKey, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace', letterSpacing: 6)),
                  const SizedBox(height: 12),
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
            const SizedBox(height: 12),

            // Disconnect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _disconnectKey(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF555555)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('연동 해제 (키 변경)', style: TextStyle(fontSize: 13, color: Color(0xFFEF5350))),
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
  Future<void> _openDownload() async {
    final uri = Uri.parse(widget.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF22223A),
      title: const Text('업데이트 알림', style: TextStyle(color: Colors.white)),
      content: Text('새 버전 ${widget.newVersion}이 있습니다.\n현재 버전: $appVersion',
          style: TextStyle(color: Colors.white.withAlpha(200))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('나중에', style: TextStyle(color: Colors.white.withAlpha(128))),
        ),
        ElevatedButton(
          onPressed: _openDownload,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA78BFA)),
          child: const Text('업데이트', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
