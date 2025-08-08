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
              Text("나른한 오후, 졸지말고 아자아자!", style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 20),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = CalendarFormat.week;
              });
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
