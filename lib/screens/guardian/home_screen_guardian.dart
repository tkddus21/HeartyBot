import 'package:flutter/material.dart';
import 'guardian_report_screen.dart';
import 'guardian_emotion_diary_screen.dart';
import 'guardian_chat_log_screen.dart';
import 'guardian_medication_screen.dart';
import 'guardian_alert_screen.dart';
import 'package:ddobaki_app/screens/settings_screen_second.dart';

class HomeScreenGuardian extends StatefulWidget {
  @override
  _HomeScreenGuardianState createState() => _HomeScreenGuardianState();
}

class _HomeScreenGuardianState extends State<HomeScreenGuardian> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    GuardianReportScreen(),
    GuardianEmotionDiaryScreen(),
    GuardianChatLogScreen(),
    GuardianMedicationScreen(),
    GuardianAlertScreen(),
  ];

  final List<String> _titles = [
    "오늘의 리포트",
    "감정 일지",
    "대화 기록",
    "약 복용 기록",
    "긴급 알림",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F5FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF7B61FF),
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsScreenSecond()),
            );
          },
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF7B61FF),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "리포트"),
          BottomNavigationBarItem(icon: Icon(Icons.insert_emoticon), label: "감정일지"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "대화"),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: "약복용"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "알림"),
        ],
      ),
    );
  }
}
