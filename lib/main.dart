import 'package:flutter/material.dart';

void main() {
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFA78BFA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  '🎮',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tam Studio',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'BPSR Companion',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(128),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'v0.1.0',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withAlpha(77),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
