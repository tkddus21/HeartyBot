import 'package:flutter/material.dart';
import 'guardian_report_screen.dart';
import 'guardian_emotion_diary_screen.dart';
import 'guardian_chat_log_screen.dart';
import 'guardian_medication_screen.dart';
import 'guardian_alert_screen.dart';
import '../settings_screen_second.dart';

class HomeScreenGuardian extends StatefulWidget {
  const HomeScreenGuardian({super.key});
  @override
  State<HomeScreenGuardian> createState() => _HomeScreenGuardianState();
}

class _HomeScreenGuardianState extends State<HomeScreenGuardian> {
  final _purple = const Color(0xFF7B61FF);
  final _bg = const Color(0xFFF6F5FC);
  int _idx = 0;

  final _pages = const [
    GuardianReportScreen(),
    GuardianEmotionDiaryScreen(),
    GuardianChatLogScreen(),
    GuardianMedicationScreen(),
    GuardianAlertScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        // 왼쪽 상단 톱니바퀴 버튼
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreenSecond()),
            );
          },
        ),
        // 스샷 텍스트에 맞춤
        title: const Text('담당 어르신 요약'),
      ),
      body: _pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        selectedItemColor: _purple,
        unselectedItemColor: const Color(0xFFBDBDBD),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions), label: '감정'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '대화'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: '약'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: '알림'),
        ],
      ),
    );
  }
}
