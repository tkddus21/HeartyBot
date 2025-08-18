import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _brandPurple = Color(0xFF9B8CF6);
const _lightBg = Color(0xFFF7F6FD);
const _border = Color(0x1A9B8CF6);

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

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

  Future<void> _deleteMedication(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final db = FirebaseFirestore.instance;
    final medId = doc.id;
    try {
      await doc.reference.delete();

      // 연결된 모든 doses 삭제 (선택)
      final qs = await db.collectionGroup('doses').where('medId', isEqualTo: medId).get();
      WriteBatch b = db.batch();
      int cnt = 0;
      for (final d in qs.docs) {
        b.delete(d.reference);
        cnt++;
        if (cnt % 450 == 0) {
          await b.commit();
          b = db.batch();
        }
      }
      await b.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );
    } on FirebaseException catch (e) {
      debugPrint('삭제 실패: ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: ${e.code}')),
      );
    }
  }

  Future<void> _editMed(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final times = (data['times'] as List?)?.cast<String>() ?? [];
    final timeCtrl = TextEditingController(text: times.isNotEmpty ? times.first : '');

    DateTime? startAt = (data['startAt'] as Timestamp?)?.toDate();
    DateTime? endAt = (data['endAt'] as Timestamp?)?.toDate();

    String _fmt(DateTime? d) =>
        d == null ? '선택 안됨' : DateFormat('yyyy-MM-dd').format(d);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          Future<void> _pickStart() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startAt ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              startAt = DateTime(picked.year, picked.month, picked.day);
              if (endAt != null && endAt!.isBefore(startAt!)) {
                endAt = startAt;
              }
              setSheetState(() {});
            }
          }

          Future<void> _pickEnd() async {
            final init = endAt ?? startAt ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: init,
              firstDate: startAt ?? DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
              setSheetState(() {});
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.edit, color: _brandPurple),
                    SizedBox(width: 6),
                    Text('약 정보 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '약 이름'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(labelText: '복용 시간 (예: 12:00)'),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('복용 시작일: ${_fmt(startAt)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickStart,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: Text('복용 종료일: ${_fmt(endAt)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickEnd,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final time = timeCtrl.text.trim();
                      if (name.isEmpty) return;

                      if (startAt == null || endAt == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('복용 시작일/종료일을 선택해 주세요.')),
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
                    child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _onLongPress(DocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: _brandPurple),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(context);
                _editMed(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('삭제'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('삭제할까요?'),
                    content: const Text('해당 약과 연결된 체크 항목도 함께 삭제됩니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok == true) {
                  await _deleteMedication(doc);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _goToAddPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _MedicationAddScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('약 관리'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _brandPurple,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddPage,
        backgroundColor: _brandPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('약 추가'),
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
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: meds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = meds[i];
              final m = doc.data();
              final name = (m['name'] ?? '') as String;
              final times = (m['times'] as List?)?.cast<String>() ?? [];
              final timeLabel = times.isEmpty ? '-' : times.join(' · ');
              final startAt = (m['startAt'] as Timestamp?)?.toDate();
              final endAt = (m['endAt'] as Timestamp?)?.toDate();
              final rangeLabel = (startAt != null && endAt != null)
                  ? '${DateFormat('yyyy.MM.dd').format(startAt)} ~ ${DateFormat('yyyy.MM.dd').format(endAt)}'
                  : '-';
              final days = (m['daysOfWeek'] as List?)?.cast<int>() ?? [];
              final isActive = (m['active'] as bool?) ?? true;

              return InkWell(
                onLongPress: () => _onLongPress(doc),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _brandPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_hospital, color: _brandPurple, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('비활성', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('복용 시간: $timeLabel',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('기간: $rangeLabel',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            if (days.isNotEmpty)
                              Text('요일: ${_daysLabel(days)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _daysLabel(List<int> days) {
    // 0=일..6=토
    const ko = ['일', '월', '화', '수', '목', '금', '토'];
    return days.map((d) => (d >= 0 && d < 7) ? ko[d] : '$d').join(', ');
  }
}

/// ===== 약 추가 화면 =====
class _MedicationAddScreen extends StatefulWidget {
  const _MedicationAddScreen({super.key});
  @override
  State<_MedicationAddScreen> createState() => _MedicationAddScreenState();
}

class _MedicationAddScreenState extends State<_MedicationAddScreen> {
  final _nameController = TextEditingController();

  /// 여러 시간(“HH:mm”)과 요일(0=일..6=토)
  final List<String> _times = <String>[];
  final Set<int> _selectedDows = <int>{};

  DateTime? _startDate;
  DateTime? _endDate;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final t = _formatTimeOfDay(picked);
      if (!_times.contains(t)) {
        setState(() {
          _times.add(t);
          _times.sort(); // 시간 정렬(오름차순)
        });
      }
    }
  }

  void _removeTime(String t) {
    setState(() => _times.remove(t));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        // 시작일을 바꾸면 종료일 최소값 보장
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      // 종료일은 하루의 끝(23:59:59)로 저장
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _addMedication() async {
    final name = _nameController.text.trim();
    final startDate = _startDate;
    final endDate = _endDate;

    if (name.isEmpty || _times.isEmpty || startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약 이름/시간/기간을 모두 입력해 주세요.')),
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
        'times': _times, // 여러 시간
        'startAt': Timestamp.fromDate(
          DateTime(startDate.year, startDate.month, startDate.day),
        ),
        'endAt': Timestamp.fromDate(endDate),
        //## 비워두면 "매일"로 해석하게끔(리스트가 비면 매일로 처리) ##
        'daysOfWeek': _selectedDows.toList()..sort(), // 0=일..6=토
        'active': true,
        'status': 'pending',
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
    final startText = _startDate != null ? _formatDate(_startDate!) : '선택 안됨';
    final endText = _endDate != null ? _formatDate(_endDate!) : '선택 안됨';
    const dowLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('약 추가하기'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _brandPurple,
        elevation: 0.5,
      ),
      backgroundColor: _lightBg,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(children: [
            // 약 이름
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '약 이름',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 12),

            // 시간 다중 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('복용 시간', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add),
                  label: const Text('시간 추가'),
                ),
              ],
            ),
            if (_times.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('아직 추가된 시간이 없습니다.'),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 16)),
                        onDeleted: () => _removeTime(t),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 12),

            // 요일 선택
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('요일 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final selected = _selectedDows.contains(i);
                return FilterChip(
                  label: Text(dowLabels[i]),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      v ? _selectedDows.add(i) : _selectedDows.remove(i);
                    });
                  },
                );
              }),
            ),

            const SizedBox(height: 12),

            // 시작/종료일
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _border),
              ),
              title: Text('복용 시작일: $startText', style: const TextStyle(fontSize: 18)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _border),
              ),
              title: Text('복용 종료일: $endText', style: const TextStyle(fontSize: 18)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickEndDate,
            ),

            const SizedBox(height: 12),

            // 저장 버튼
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
      ),
    );
  }
}
