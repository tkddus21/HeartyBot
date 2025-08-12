// home_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'diary_screen.dart';
import 'medication_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 🔧 현재 시간에 맞는 인사말을 반환하는 함수
  String _getGreeting() {
    final int hour = DateTime.now().hour;

    if (hour >= 7 && hour < 12) {
      return "활기찬 오전, 기분 좋게 보내세요.";
    } else if (hour >= 12 && hour < 18) {
      return "점심은 든든히 드셨나요?";
    } else if (hour >= 18 && hour < 22) {
      return "편안한 저녁 시간 보내세요.";
    } else {
      return "포근한 밤, 좋은 꿈 꾸세요.";
    }
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildMedicationStatusCard() {
    final selectedDateStr = _formatDate(_selectedDay ?? DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('medications').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(child: Padding(padding: EdgeInsets.all(16), child: Text('데이터 로딩 중...')));
        }

        final meds = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = data['startDate'];
          final end = data['endDate'];
          return start != null && end != null &&
              selectedDateStr.compareTo(start) >= 0 &&
              selectedDateStr.compareTo(end) <= 0;
        }).toList();

        final allTaken = meds.every((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['taken'] == true;
        });

        return Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("약 복용: ${meds.isEmpty ? '데이터 없음' : (allTaken ? '✅ 완료' : '❌ 미복용')}"),
                SizedBox(height: 12),
                ...meds.map((doc) {
                  final med = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          med['taken'] == true ? Icons.check_circle : Icons.cancel,
                          color: med['taken'] == true ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text("${med['name']} (${med['time']})")),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.grey[300]),
              SizedBox(width: 12),
              // 🔧 기존 Text 위젯을 함수 호출로 변경
              Text(_getGreeting(), style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 20),
          // 🔧 GestureDetector로 달력을 감싸 스와이프 방향을 직접 제어합니다.
          GestureDetector(
            onVerticalDragEnd: (details) {
              // 아래로 스와이프하면 (속도가 양수)
              if (details.primaryVelocity! > 0) {
                setState(() {
                  _calendarFormat = CalendarFormat.month; // 월간 달력으로 변경
                });
              }
              // 위로 스와이프하면 (속도가 음수)
              else if (details.primaryVelocity! < 0) {
                setState(() {
                  _calendarFormat = CalendarFormat.week; // 주간 달력으로 변경
                });
              }
            },
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              // 🔧 달력 자체의 스와이프 기능은 끕니다.
              availableGestures: AvailableGestures.none,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.5), shape: BoxShape.circle),
              ),
              headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),
          SizedBox(height: 20),
          _buildMedicationStatusCard(),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return ChatScreen();
      case 2:
        return DiaryScreen();
      case 3:
        return MedicationScreen();
      default:
        return _buildHomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        title: Text("또바기 홈"),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '챗봇'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '일기'),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: '약'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
