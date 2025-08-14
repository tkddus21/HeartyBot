import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _brandPurple = Color(0xFF6A4CFE);

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // 홈 화면(캘린더)에서 오늘 도즈가 필요할 수 있어 유지
    ensureTodayDoses(_uid);
  }

  // 날짜 무관 "약 목록" 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _medicationsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('medications')
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? {},
      toFirestore: (d, _) => d,
    )
        .snapshots();
  }

  // 수정 시트
  Future<void> _editMed(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final times = (data['times'] as List?)?.cast<String>() ?? [];
    final timeCtrl = TextEditingController(text: times.isNotEmpty ? times.first : '');

    DateTime? startAt = (data['startAt'] as Timestamp?)?.toDate();
    DateTime? endAt   = (data['endAt'] as Timestamp?)?.toDate();

    String _fmt(DateTime? d) =>
        d == null ? '선택 안됨' : DateFormat('yyyy-MM-dd').format(d);

    Future<void> _pickStartDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: startAt ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        startAt = DateTime(picked.year, picked.month, picked.day);
        if (endAt != null && endAt!.isBefore(startAt!)) {
          // 시작일이 종료일보다 커지면 종료일을 시작일로 자동 보정
          endAt = startAt;
        }
        // setState가 아닌 모달 내부 리빌드를 위해 Navigator root의 context가 아닌 StatefulBuilder 사용
      }
    }

    Future<void> _pickEndDate() async {
      final init = endAt ?? startAt ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: init,
        firstDate: startAt ?? DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // 내부에서 날짜 선택 후 UI 갱신을 위해 setSheetState 사용
            Future<void> pickStart() async { await _pickStartDate(); setSheetState((){}); }
            Future<void> pickEnd() async { await _pickEndDate(); setSheetState((){}); }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.edit, color: _brandPurple),
                      SizedBox(width: 8),
                      Text('약 정보 수정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 약 이름
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '약 이름'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // 복용 시간(첫 항목만 간단 수정)
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(labelText: '복용 시간 (예: 12:00)'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // 시작/종료일
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _brandPurple.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                      color: _brandPurple.withOpacity(0.03),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('복용 시작일: ${_fmt(startAt)}',
                              style: const TextStyle(fontSize: 18)),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: pickStart,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: Text('복용 종료일: ${_fmt(endAt)}',
                              style: const TextStyle(fontSize: 18)),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: pickEnd,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final time = timeCtrl.text.trim();
                        if (name.isEmpty) return;

                        if (startAt == null || endAt == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('복용 시작일과 종료일을 선택해 주세요.')),
                          );
                          return;
                        }
                        if (endAt!.isBefore(startAt!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('종료일은 시작일 이후여야 합니다.')),
                          );
                          return;
                        }

                        await doc.reference.update({
                          'name': name,
                          'times': time.isEmpty ? [] : [time],
                          'startAt': Timestamp.fromDate(
                            DateTime(startAt!.year, startAt!.month, startAt!.day),
                          ),
                          'endAt': Timestamp.fromDate(
                            DateTime(endAt!.year, endAt!.month, endAt!.day, 23, 59, 59),
                          ),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('저장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 삭제 (관련 도즈도 함께 삭제: collectionGroup 검색)
  Future<void> _deleteMed(String medId, String medName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제'),
        content: Text('[$medName]을(를) 삭제하시겠어요?\n(연결된 복용 체크도 함께 삭제됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    final db = FirebaseFirestore.instance;
    // 1) 마스터 삭제
    await db.collection('users').doc(_uid).collection('medications').doc(medId).delete();

    // 2) 모든 days/*/doses 중 해당 medId 삭제 (collectionGroup)
    final qs = await db
        .collectionGroup('doses')
        .where('medId', isEqualTo: medId)
        .get();

    // 배치로 삭제
    WriteBatch b = db.batch();
    int count = 0;
    for (final d in qs.docs) {
      b.delete(d.reference);
      count++;
      if (count % 450 == 0) { // 안전 버퍼
        await b.commit();
        b = db.batch();
      }
    }
    await b.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('[$medName] 및 연결된 항목이 삭제되었습니다.')),
    );
  }

  // 롱프레스 액션 시트
  Future<void> _showItemActions(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final medName = (data['name'] ?? '') as String;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: _brandPurple),
                  title: const Text('수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(context);
                    _editMed(doc);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('삭제', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteMed(doc.id, medName);
                  },
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToAddPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationAddScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약 관리'),
        foregroundColor: _brandPurple,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddPage,
        backgroundColor: _brandPurple,
        icon: const Icon(Icons.add),
        label: const Text('약 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _medicationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final meds = snapshot.data?.docs ?? [];
          if (meds.isEmpty) {
            return Center(
              child: Text(
                '등록된 약이 없습니다.\n오른쪽 아래에서 추가해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.grey[700]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: meds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = meds[i];
              final m = doc.data();
              final name = (m['name'] ?? '') as String;
              final times = (m['times'] as List?)?.cast<String>() ?? [];
              final timeLabel = times.isEmpty ? '' : times.join(' · ');
              final startAt = (m['startAt'] as Timestamp?)?.toDate();
              final endAt = (m['endAt'] as Timestamp?)?.toDate();
              final rangeLabel = (startAt != null && endAt != null)
                  ? '${DateFormat('yyyy.MM.dd').format(startAt)} ~ ${DateFormat('yyyy.MM.dd').format(endAt)}'
                  : '';
              final active = (m['active'] == true);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _brandPurple.withOpacity(0.18)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Row(
                    children: [
                      Icon(Icons.medication, color: _brandPurple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!active)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Chip(label: Text('비활성'), visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('복용 시간: $timeLabel',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ),
                      if (rangeLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('기간: $rangeLabel',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ),
                      if ((m['daysOfWeek'] as List?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '요일: ${(m['daysOfWeek'] as List).join(', ')}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                  onLongPress: () => _showItemActions(doc), // ⟵ 롱프레스 액션
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
        'times': [time],
        'startAt': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
        'endAt': Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)),
        'daysOfWeek': [], // 0=일..6=토
        'active': true,
        'status': 'pending', // Firestore 규칙 호환
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
      appBar: AppBar(
        title: const Text('약 추가하기'),
        foregroundColor: _brandPurple,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '약 이름', border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('복용 시간: $timeText', style: const TextStyle(fontSize: 18)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          ListTile(
            title: Text('복용 시작일: $startText', style: const TextStyle(fontSize: 18)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickStartDate,
          ),
          ListTile(
            title: Text('복용 종료일: $endText', style: const TextStyle(fontSize: 18)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickEndDate,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.check),
              label: const Text('저장', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

//
// ====== 유틸 & 오늘의 도즈 생성 (홈 캘린더용) ======
//
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
      });
    }
  }

  await batch.commit();
}
