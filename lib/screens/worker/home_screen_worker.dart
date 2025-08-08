import 'package:flutter/material.dart';
import 'worker_dashboard_screen.dart';
import 'worker_emotion_summary_screen.dart';
import 'worker_medication_summary_screen.dart';
import 'worker_alert_screen.dart';
import 'worker_note_screen.dart';
import 'package:ddobaki_app/screens/settings_screen_second.dart';

class HomeScreenWorker extends StatefulWidget {
  @override
  _HomeScreenWorkerState createState() => _HomeScreenWorkerState();
}

class _HomeScreenWorkerState extends State<HomeScreenWorker> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    WorkerDashboardScreen(),
    WorkerEmotionSummaryScreen(),
    WorkerMedicationSummaryScreen(),
    WorkerAlertScreen(),
    WorkerNoteScreen(),
  ];

  final List<String> _titles = [
    "담당 어르신 요약",
    "감정 리포트",
    "복약 상태",
    "이상 알림",
    "간단 메모",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F5FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF7B61FF),
        title: Text(_titles[_selectedIndex], style: TextStyle(color: Colors.white)),
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_emoticon), label: '감정'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: '복약'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: '메모'),
        ],
      ),
    );
  }
}
