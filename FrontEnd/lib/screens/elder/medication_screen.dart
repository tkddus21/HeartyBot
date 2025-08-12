import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _todayId => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 오늘의 체크리스트 보장
    ensureTodayDoses(_uid);
  }

  Future<void> _toggleTaken(DocumentReference docRef, bool taken) async {
    final now = FieldValue.serverTimestamp();
    await docRef.update(
      taken
          ? {'status': 'taken', 'takenAt': now, 'updatedAt': now}
          : {'status': 'pending', 'takenAt': null, 'updatedAt': now},
    );
  }

  void _goToAddPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicationAddScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dosesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('days')
        .doc(_todayId)
        .collection('doses')
        .orderBy('scheduledAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('약 복용 리스트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _goToAddPage,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: dosesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('오늘 복용할 약이 없어요.'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index];
              final m = d.data() as Map<String, dynamic>;
              final taken = (m['status'] == 'taken');
              final dt = (m['scheduledAt'] as Timestamp?)?.toDate();
              final timeStr = dt != null ? DateFormat('HH:mm').format(dt) : '';

              return ListTile(
                title: Text(m['medName'] ?? ''),
                subtitle: Text(timeStr),
                trailing: taken
                    ? IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _toggleTaken(d.reference, false),
                        tooltip: '체크 해제',
                      )
                    : ElevatedButton(
                        onPressed: () => _toggleTaken(d.reference, true),
                        child: const Text('복용'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 약 정의/스케줄 추가 화면
class MedicationAddScreen extends StatefulWidget {
  const MedicationAddScreen({super.key});
  @override
  State<MedicationAddScreen> createState() => _MedicationAddScreenState();
}

class _MedicationAddScreenState extends State<MedicationAddScreen> {
  final _nameController = TextEditingController();
  TimeOfDay? _selectedTime;
  DateTime? _startDate;
  DateTime? _endDate;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _addMedication() async {
    final name = _nameController.text.trim();
    final time = _selectedTime != null ? _formatTime(_selectedTime!) : '';
    final startDate = _startDate;
    final endDate = _endDate;

    if (name.isEmpty || time.isEmpty || startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 값을 입력해 주세요.')),
      );
      return;
    }

    final medsCol = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('medications');

    final now = FieldValue.serverTimestamp();

    try {
      await medsCol.add({
        'name': name,
        // 확장을 위해 times는 배열로 저장 (지금은 1개만)
        'times': [time], // e.g., ["08:00"]
        // 날짜는 Timestamp로 저장(문자열보다 안전)
        'startAt': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
        'endAt': Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)),
        // 요일 제한이 없다면 빈 배열 (추후 Mon~Sun 필터를 추가 가능)
        'daysOfWeek': [], // 0=일..6=토 (빈 배열이면 매일)
        'active': true,
        'createdAt': now,
        'updatedAt': now,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _selectedTime != null ? _formatTime(_selectedTime!) : '선택 안됨';
    final startText = _startDate != null ? _formatDate(_startDate!) : '선택 안됨';
    final endText = _endDate != null ? _formatDate(_endDate!) : '선택 안됨';

    return Scaffold(
      appBar: AppBar(title: const Text('약 추가하기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '약 이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('복용 시간: $timeText'),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          ListTile(
            title: Text('복용 시작일: $startText'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickStartDate,
          ),
          ListTile(
            title: Text('복용 종료일: $endText'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickEndDate,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _addMedication, child: const Text('약 추가하기')),
        ]),
      ),
    );
  }
}

/// ====== 유틸 & 오늘의 도즈 생성 ======

String todayId(DateTime now) => DateFormat('yyyy-MM-dd').format(now);

bool _isWithinDay(DateTime day, DateTime start, DateTime end) {
  final d = DateTime(day.year, day.month, day.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

/// 앱/화면 진입 시 1회 호출: 오늘 체크리스트(doses) 자동 생성
Future<void> ensureTodayDoses(String uid) async {
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final dayId = todayId(now);

  final dayRef = db.collection('users').doc(uid).collection('days').doc(dayId);
  final dosesRef = dayRef.collection('doses');

  // 이미 생성되어 있으면 스킵
  final exist = await dosesRef.limit(1).get();
  if (exist.docs.isNotEmpty) return;

  final medsSnap = await db
      .collection('users')
      .doc(uid)
      .collection('medications')
      .where('active', isEqualTo: true)
      .get();

  final batch = db.batch();

  // days 컨테이너 보장
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
    if (!_isWithinDay(now, startAt, endAt)) continue;

    // 요일 필터 (0=일..6=토)
    final daysOfWeek = (med['daysOfWeek'] as List?)?.cast<int>() ?? [];
    if (daysOfWeek.isNotEmpty) {
      // Dart: Mon=1..Sun=7 → 0..6으로 변환
      final dow0 = (now.weekday == DateTime.sunday) ? 0 : now.weekday; // Sun=0, Mon=1..Sat=6
      if (!daysOfWeek.contains(dow0)) continue;
    }

    for (final t in times) {
      // "HH:mm" → 오늘의 DateTime
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      final sched = DateTime(now.year, now.month, now.day, hh, mm);

      // 중복 방지 키 → doseId
      final key = '${m.id}_${DateFormat('yyyyMMdd').format(now)}_$t';
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
      }, SetOptions(merge: false));
    }
  }

  await batch.commit();
}
