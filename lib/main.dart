import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        const BuffMonitorPage(),
        const DropTrackerPage(),
      ][_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: const Color(0xFF16162A),
        indicatorColor: const Color(0xFF2A2A4E),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield), label: '버프'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: '드랍'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Buff Monitor Page
// ══════════════════════════════════════

class BuffMonitorPage extends StatefulWidget {
  const BuffMonitorPage({super.key});

  @override
  State<BuffMonitorPage> createState() => _BuffMonitorPageState();
}

class _BuffMonitorPageState extends State<BuffMonitorPage> {
  List<Map<String, dynamic>> _buffs = [];

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance.ref('buffs');
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
  const DropTrackerPage({super.key});

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
    final ref = FirebaseDatabase.instance.ref('drops');
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
