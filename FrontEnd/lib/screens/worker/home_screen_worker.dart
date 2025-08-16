import 'package:flutter/material.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import
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

  // 🔧 현재 선택된 어르신 정보를 저장할 상태 변수
  Elder? _selectedElder;

  // 🔧 대시보드에서 어르신이 선택되었을 때 호출될 함수
  void _onElderSelected(Elder elder) {
    setState(() {
      _selectedElder = elder;
    });
    // 감정 리포트 탭으로 자동 이동하여 사용자 경험 개선
    _onBottomNavTapped(1);
  }

  // 🔧 하단 네비게이션 탭을 눌렀을 때 호출될 함수
  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 화면 목록을 build 메소드 안에서 동적으로 생성
    final List<Widget> screens = [
      // 대시보드에는 어르신 선택 시 호출할 함수를 전달
      WorkerDashboardScreen(onElderSelected: _onElderSelected, selectedElder: _selectedElder),
      // 다른 화면들에는 현재 선택된 어르신 정보를 전달
      WorkerEmotionSummaryScreen(selectedElder: _selectedElder),
      WorkerMedicationSummaryScreen(selectedElder: _selectedElder),
      WorkerAlertScreen(selectedElder: _selectedElder),
      WorkerNoteScreen(selectedElder: _selectedElder),
    ];

    final List<String> titles = [
      "담당 어르신 요약",
      // 🔧 선택된 어르신이 있으면 AppBar 제목에 이름을 표시
      _selectedElder == null ? "감정 리포트" : "${_selectedElder!.name}님 감정 리포트",
      _selectedElder == null ? "복약 상태" : "${_selectedElder!.name}님 복약 상태",
      "이상 알림",
      _selectedElder == null ? "간단 메모" : "${_selectedElder!.name}님 메모",
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF6F5FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF7B61FF),
        title: Text(titles[_selectedIndex], style: TextStyle(color: Colors.white)),
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
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF7B61FF),
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavTapped,
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
