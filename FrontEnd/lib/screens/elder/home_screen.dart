import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

import 'chat_screen.dart';
import 'diary_screen.dart';
import 'medication_screen.dart';

/// 공통 색상 (부드러운 라벤더 톤)
const _brandPurple = Color(0xFF9B8CF6);
const _lightBg = Color(0xFFF7F6FD);
const _border = Color(0x1A9B8CF6); // 10% 보라

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  StreamSubscription? _medsSub;
  Timer? _recomputeDebounce;

  // ===== 알림 허용/차단 상태 =====
  bool _notificationsEnabled = true;
  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    ensureDosesForDate(uid, _focusedDay); // 시작 시 포커스 날짜 생성 보장

    // 약 목록 변화 → 선택 날짜 도즈 재계산(디바운스)
    final medsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications');

    _medsSub = medsRef.snapshots().listen((_) {
      _recomputeDebounce?.cancel();
      _recomputeDebounce = Timer(const Duration(milliseconds: 300), () {
        recomputeDosesForDate(uid, _selectedDay ?? DateTime.now());
      });
    });

    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final snap = await _userDoc.get();
      final enabled = (snap.data()?['notificationsEnabled'] as bool?) ?? true;
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      // 문제 있어도 기본값(true) 유지
    }
  }

  Future<void> _toggleNotifications() async {
    final next = !_notificationsEnabled;
    setState(() => _notificationsEnabled = next);

    try {
      await _userDoc.set(
        {'notificationsEnabled': next, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next ? '알림을 켰습니다.' : '알림을 껐습니다.')),
      );
    } catch (e) {
      // 실패 시 롤백
      if (mounted) setState(() => _notificationsEnabled = !next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 설정을 저장하지 못했습니다.')),
      );
    }
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    _medsSub?.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 12) return "활기찬 오전, 기분 좋게 보내세요.";
    if (hour >= 12 && hour < 18) return "점심은 든든히 드셨나요?";
    if (hour >= 18 && hour < 22) return "편안한 저녁 시간 보내세요.";
    return "포근한 밤, 좋은 꿈 꾸세요.";
  }

  void _onBottomNavTapped(int index) => setState(() => _selectedIndex = index);

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// 홈 바디(캘린더 + 약 카드)
  Widget _buildHomeBody() {
    return Container(
      color: _lightBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // 인사 + 마스코트
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('assets/mascot2.jpg'), // ✅ 마스코트
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _getGreeting(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

// 캘린더
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: TableCalendar(
                locale: 'ko_KR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,

                // ✅ 주/월 전환 허용 (위/아래 스와이프로 변경)
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.week: 'Week',
                  CalendarFormat.month: 'Month',
                },
                availableGestures: AvailableGestures.all, // 위/아래: 형식 전환, 좌/우: 달 이동

                // ✅ 요일 헤더 잘리면 높이 늘리기 (선택)
                daysOfWeekHeight: 22.0,

                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) async {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  await recomputeDosesForDate(uid, selectedDay);
                },

                // ✅ 주말 색상 지정 (요일 헤더 + 날짜 셀)
                calendarBuilders: CalendarBuilders(
                  // 요일 헤더(일~토)
                  dowBuilder: (context, day) {
                    switch (day.weekday) {
                      case DateTime.sunday:
                        return const Center(child: Text('일', style: TextStyle(color: Colors.red)));
                      case DateTime.saturday:
                        return const Center(child: Text('토', style: TextStyle(color: Colors.blue)));
                      default:
                        return Center(child: Text(DateFormat.E('ko_KR').format(day)));
                    }
                  },
                  // 날짜 셀(숫자)
                  defaultBuilder: (context, day, focusedDay) {
                    switch (day.weekday) {
                      case DateTime.sunday:
                        return Center(child: Text('${day.day}', style: const TextStyle(color: Colors.red)));
                      case DateTime.saturday:
                        return Center(child: Text('${day.day}', style: const TextStyle(color: Colors.blue)));
                      default:
                        return null; // 기본 렌더링 사용
                    }
                  },
                ),

                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: _brandPurple,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: _brandPurple.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  // 참고: 아래 weekendTextStyle은 defaultBuilder가 있으면 덮어써집니다.
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  // 필요 시 월간에서 다른 달 날짜 숨기기
                  // outsideDaysVisible: false,
                ),

                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 18.0),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 약 복용 카드
            _MedicationStatusCard(
              day: _selectedDay ?? DateTime.now(),
              fmtDate: _fmtDate,
            ),
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
    final notiIcon =
    _notificationsEnabled ? Icons.notifications : Icons.notifications_off;

    return Scaffold(
      appBar: AppBar(
        title: const Text('또바기'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _brandPurple,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        actions: [
          IconButton(
            tooltip: _notificationsEnabled ? '알림 끄기' : '알림 켜기',
            icon: Icon(notiIcon),
            onPressed: _toggleNotifications, // ✅ 토글 동작
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

/// 약 복용 카드 위젯 (선택 날짜 기준)
class _MedicationStatusCard extends StatelessWidget {
  final DateTime day;
  final String Function(DateTime) fmtDate;

  const _MedicationStatusCard({required this.day, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dayId = fmtDate(day);

    final dosesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('days')
        .doc(dayId)
        .collection('doses');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: dosesRef.orderBy('scheduledAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            final isToday = DateUtils.isSameDay(day, DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader('약 복용'),
                const SizedBox(height: 6),
                Text(
                  isToday ? '오늘 복용할 약이 없습니다.' : '해당 날짜에 복용 일정이 없습니다.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandPurple,
                    side: BorderSide(color: _brandPurple.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    await ensureDosesForDate(uid, day);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text('${fmtDate(day)} 체크리스트 생성'),
                ),
              ],
            );
          }

          final total = docs.length;
          final taken = docs.where((d) => (d.data()['status'] == 'taken')).length;
          final progress = total == 0 ? 0.0 : taken / total;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('약 복용'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: _brandPurple.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(_brandPurple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$taken / $total', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
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
              )
            ],
          );
        },
      ),
    );
  }

  static Widget _cardHeader(String title) => Row(
    children: [
      const Icon(Icons.medication_liquid, color: _brandPurple, size: 20),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    ],
  );
}

/// ====== 유틸 & 특정 날짜 도즈 생성/재계산 ======

String _dayId(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

bool _isWithinDay(DateTime day, DateTime start, DateTime end) {
  final d = DateTime(day.year, day.month, day.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

/// 선택한 날짜의 doses를 보장(없으면 생성)
Future<void> ensureDosesForDate(String uid, DateTime day) async {
  final db = FirebaseFirestore.instance;
  final dayId = _dayId(day);
  final dayRef = db.collection('users').doc(uid).collection('days').doc(dayId);
  final dosesRef = dayRef.collection('doses');

  final exist = await dosesRef.limit(1).get();
  if (exist.docs.isNotEmpty) return;

  final medsSnap = await db
      .collection('users')
      .doc(uid)
      .collection('medications')
      .where('active', isEqualTo: true)
      .get();

  final batch = db.batch();

  batch.set(dayRef, {
    'date': dayId,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  for (final m in medsSnap.docs) {
    final med = m.data();
    final name = med['name'] as String? ?? '';
    final times = (med['times'] as List?)?.cast<String>() ?? [];

    final startAt = (med['startAt'] as Timestamp?)?.toDate();
    final endAt = (med['endAt'] as Timestamp?)?.toDate();
    if (startAt == null || endAt == null) continue;
    if (!_isWithinDay(day, startAt, endAt)) continue;

    final daysOfWeek = (med['daysOfWeek'] as List?)?.cast<int>() ?? [];
    if (daysOfWeek.isNotEmpty) {
      final dow0 = (day.weekday == DateTime.sunday) ? 0 : day.weekday; // Sun=0
      if (!daysOfWeek.contains(dow0)) continue;
    }

    for (final t in times) {
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      final sched = DateTime(day.year, day.month, day.day, hh, mm);

      final key = '${m.id}_${DateFormat('yyyyMMdd').format(day)}_$t';
      final doseId = sha1.convert(utf8.encode(key)).toString();

      batch.set(dosesRef.doc(doseId), {
        'medId': m.id,
        'medName': name,
        'scheduledAt': Timestamp.fromDate(sched),
        'status': 'pending',
        'takenAt': null,
        'sourceKey': key,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  await batch.commit();
}

/// 선택한 날짜의 doses를 전부 지우고 다시 생성
Future<void> recomputeDosesForDate(String uid, DateTime day) async {
  final db = FirebaseFirestore.instance;
  final dayId = _dayId(day);
  final dosesRef =
  db.collection('users').doc(uid).collection('days').doc(dayId).collection('doses');

  final snap = await dosesRef.get();
  if (snap.docs.isNotEmpty) {
    WriteBatch b = db.batch();
    int cnt = 0;
    for (final d in snap.docs) {
      b.delete(d.reference);
      cnt++;
      if (cnt % 450 == 0) {
        await b.commit();
        b = db.batch();
      }
    }
    await b.commit();
  }
  await ensureDosesForDate(uid, day);
}
