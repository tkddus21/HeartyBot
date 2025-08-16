import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'diary_screen.dart';
import 'medication_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


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
    ensureTodayDoses(FirebaseAuth.instance.currentUser!.uid); // 오늘 날짜 체크리스트 생성 보장
  }

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
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final selected = _selectedDay ?? DateTime.now();
  final dayId = DateFormat('yyyy-MM-dd').format(selected);

  final dosesRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('days')
      .doc(dayId)
      .collection('doses');

  return Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: dosesRef.orderBy('scheduledAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            final isToday = DateUtils.isSameDay(selected, DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('약 복용', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(isToday ? '오늘 복용할 약이 없습니다.' : '해당 날짜에 복용 일정이 없습니다.'),
                if (isToday) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ensureTodayDoses(uid);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('오늘 체크리스트 생성/새로고침'),
                  ),
                ],
              ],
            );
          }

          final total = docs.length;
          final taken = docs.where((d) => (d.data()['status'] == 'taken')).length;
          final progress = total == 0 ? 0.0 : taken / total;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('약 복용', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              // 진행률
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(minHeight: 8, value: progress),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$taken / $total'),
                ],
              ),

              const SizedBox(height: 12),

              // 리스트 (체크 토글 → Firestore 반영)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final medName = (data['medName'] ?? '') as String;
                  final status = (data['status'] ?? 'pending') as String;
                  final isTaken = status == 'taken';
                  final sched = (data['scheduledAt'] as Timestamp?)?.toDate();
                  final label = sched != null ? DateFormat('HH:mm').format(sched) : '-';

                  final overdue = !isTaken &&
                      sched != null &&
                      DateTime.now().isAfter(sched.add(const Duration(minutes: 30)));

                  return CheckboxListTile(
                    value: isTaken,
                    onChanged: (v) async {
                      await d.reference.update({
                        'status': v == true ? 'taken' : 'pending',
                        'takenAt': v == true ? FieldValue.serverTimestamp() : null,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: overdue ? Colors.redAccent : null,
                      ),
                    ),
                    title: Text(medName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: overdue
                        ? const Text('예정 시간 경과', style: TextStyle(color: Colors.redAccent))
                        : null,
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}



  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          // 🔧 crossAxisAlignment를 제거하여 자식 위젯들이 중앙 정렬되도록 합니다.
          children: [
            SizedBox(height: 20),
            Row(
              // 🔧 mainAxisAlignment를 center로 설정하여 중앙 정렬합니다.
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.grey[300]),
                SizedBox(width: 12),
                Flexible(
                  child: Text(_getGreeting(), style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            SizedBox(height: 20),
            TableCalendar(
              locale: 'ko_KR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.week: 'Week',
                CalendarFormat.month: 'Month',
              },
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
                todayDecoration: BoxDecoration(color: Colors.deepPurple.shade200, shape: BoxShape.circle),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 18.0),
              ),
            ),
            SizedBox(height: 20),
            _buildMedicationStatusCard(),
          ],
        ),
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
        // 🔧 AppBar를 다시 기본 스타일로 되돌리고 제목을 추가합니다.
        title: Text('또바기'),
        centerTitle: true, // 제목을 중앙에配置
        leading: IconButton(
          icon: Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
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
