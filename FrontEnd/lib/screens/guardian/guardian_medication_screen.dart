// lib/screens/guardian_medication_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // ⬅ 날짜 표시용

/// ====== 모델 ======
class Medication {
  final String id;
  final String name;
  final List<String> times;
  final bool active;
  final List<dynamic>? daysOfWeek; // 필요 시 [0..6]
  final Timestamp? startAt;
  final Timestamp? endAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Medication({
    required this.id,
    required this.name,
    required this.times,
    this.active = true,
    this.daysOfWeek,
    this.startAt,
    this.endAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Medication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Medication(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      times: (d['times'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      active: (d['active'] as bool?) ?? true,
      daysOfWeek: d['daysOfWeek'] as List?,
      startAt: d['startAt'] as Timestamp?,
      endAt: d['endAt'] as Timestamp?,
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'name': name,
      'times': times,
      'active': active,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'times': times,
      'active': active,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// ====== Firestore 접근 유틸 ======
Future<String?> _resolveElderUid() async {
  final guardianUid = FirebaseAuth.instance.currentUser?.uid;
  if (guardianUid == null) return null;

  // 보호자 문서
  final meSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(guardianUid)
      .get(const GetOptions(source: Source.server));
  final me = meSnap.data();
  if (me == null) return null;

  // 1) elderUid 있으면 바로 사용
  final elderUid = (me['elderUid'] as String?);
  if (elderUid != null && elderUid.isNotEmpty) return elderUid;

  // 2) elderEmail → email_index/{email}.uid
  final elderEmail = ((me['elderEmail'] as String?) ?? '').trim().toLowerCase();
  if (elderEmail.isEmpty) return null;

  final idxSnap = await FirebaseFirestore.instance
      .collection('email_index')
      .doc(elderEmail)
      .get(const GetOptions(source: Source.server));

  return (idxSnap.data()?['uid'] as String?);
}

CollectionReference<Map<String, dynamic>> _medsCol(String elderUid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(elderUid)
      .collection('medications');
}

Stream<List<Medication>> _watchMedications(String elderUid) {
  return _medsCol(elderUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((qs) => qs.docs.map(Medication.fromDoc).toList());
}

Future<void> _createMedication(String elderUid, Medication med) async {
  await _medsCol(elderUid).add(med.toCreateMap());
}

Future<void> _updateMedication(String elderUid, Medication med) async {
  await _medsCol(elderUid).doc(med.id).update(med.toUpdateMap());
}

Future<void> _patchMedication(
  String elderUid,
  String medId,
  Map<String, dynamic> patch,
) async {
  await _medsCol(elderUid).doc(medId).update({
    ...patch,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _deleteMedication(String elderUid, String medId) async {
  await _medsCol(elderUid).doc(medId).delete();
}

/// ====== 유틸(표시용) ======
String _fmtDate(DateTime? d) =>
    d == null ? '선택 안됨' : DateFormat('yyyy-MM-dd').format(d);

String _fmtTimeOfDay(TimeOfDay t) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
  return DateFormat('HH:mm').format(dt);
}

/// ====== 확장 입력 다이얼로그(이름/시간/활성/요일/기간) ======
/// 반환: {'name': String, 'times': List<String>, 'active': bool,
///       'daysOfWeek': List<int>, 'startAt': Timestamp, 'endAt': Timestamp}
Future<Map<String, dynamic>?> _showMedicationDialog(
  BuildContext context, {
  Medication? initial,
}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final List<String> times = [...(initial?.times ?? const <String>[])];
  bool active = initial?.active ?? true;

  // 요일: 기존 값 있으면 int 로 변환해서 셋팅
  final Set<int> dows = {
    ...(initial?.daysOfWeek?.map((e) => int.tryParse(e.toString()) ?? -1)
            .where((e) => e >= 0) ??
        const <int>[])
  };

  DateTime? startDate = initial?.startAt?.toDate();
  DateTime? endDate = initial?.endAt?.toDate();

  const dowLabels = ['일', '월', '화', '수', '목', '금', '토'];

  Future<void> pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) startDate = picked;
  }

  Future<void> pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? (startDate ?? DateTime.now()),
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) endDate = picked;
  }

  void addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final t = _fmtTimeOfDay(picked);
    if (!times.contains(t)) {
      times.add(t);
      times.sort();
    }
  }

  void removeTime(String t) => times.remove(t);

  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (ctx) {
      // 내부상태 갱신을 위해 StatefulBuilder 사용
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text(initial == null ? '약 추가' : '약 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '약 이름'),
                ),
                const SizedBox(height: 8),

                // 복용시간
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('복용 시간',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextButton.icon(
                      onPressed: () async {
                        final before = List<String>.from(times);
                        await Future<void>.delayed(Duration.zero); // no-op
                        final picked =
                            await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          final t = _fmtTimeOfDay(picked);
                          if (!times.contains(t)) {
                            setState(() {
                              times.add(t);
                              times.sort();
                            });
                          }
                        } else {
                          if (before != times) setState(() {});
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('시간 추가'),
                    ),
                  ],
                ),
                if (times.isEmpty)
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('아직 추가된 시간이 없습니다.')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: times
                      .map((t) => Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => removeTime(t)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),

                // 활성화 스위치
                SwitchListTile(
                  title: const Text('활성화'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),

                const SizedBox(height: 8),

                // 요일 선택
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('요일 선택', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (i) {
                    final selected = dows.contains(i);
                    return FilterChip(
                      label: Text(dowLabels[i]),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          v ? dows.add(i) : dows.remove(i);
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 8),

                // 기간 선택
                ListTile(
                  title: Text('복용 시작일: ${_fmtDate(startDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    await pickStart();
                    setState(() {});
                  },
                ),
                ListTile(
                  title: Text('복용 종료일: ${_fmtDate(endDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    await pickEnd();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || times.isEmpty || startDate == null || endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('약 이름/시간/기간을 모두 입력해 주세요.')),
                  );
                  return;
                }

                // Firestore 저장 포맷 맞추기
                final startTs = Timestamp.fromDate(
                  DateTime(startDate!.year, startDate!.month, startDate!.day, 0, 0, 0),
                );
                final endTs = Timestamp.fromDate(
                  DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59),
                );

                Navigator.pop(ctx, {
                  'name': name,
                  'times': times,
                  'active': active,
                  'daysOfWeek': dows.toList()..sort(), // [0..6]
                  'startAt': startTs,
                  'endAt': endTs,
                });
              },
              child: const Text('확인'),
            ),
          ],
        );
      });
    },
  );
}

/// ====== 화면 위젯 ======
class GuardianMedicationScreen extends StatefulWidget {
  const GuardianMedicationScreen({super.key});

  @override
  State<GuardianMedicationScreen> createState() => _GuardianMedicationScreenState();
}

class _GuardianMedicationScreenState extends State<GuardianMedicationScreen> {
  String? elderUid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = await _resolveElderUid();
      setState(() {
        elderUid = uid;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('노인 계정 조회 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (elderUid == null) {
      return const Scaffold(
        body: Center(child: Text('연결된 노인을 찾을 수 없습니다. (elderUid/elderEmail 확인)')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('노인 약 복용 리스트(보호자)')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await _showMedicationDialog(context);
          if (res == null) return;

          final med = Medication(
            id: 'tmp',
            name: res['name'] as String,
            times: (res['times'] as List).cast<String>(),
            active: res['active'] as bool,
            daysOfWeek: (res['daysOfWeek'] as List?)?.cast<int>(),
            startAt: res['startAt'] as Timestamp?,
            endAt: res['endAt'] as Timestamp?,
          );
          await _createMedication(elderUid!, med);
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Medication>>(
        stream: _watchMedications(elderUid!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final meds = snap.data ?? const <Medication>[];
          if (meds.isEmpty) {
            return const Center(child: Text('등록된 약이 없습니다.'));
          }
          return ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = meds[i];

              String sub = '시간: ${m.times.join(", ")}';
              if (m.daysOfWeek != null && m.daysOfWeek!.isNotEmpty) {
                const dowLabels = ['일', '월', '화', '수', '목', '금', '토'];
                final dowNames = m.daysOfWeek!
                    .map((e) => dowLabels[(e as num).toInt()])
                    .toList();
                sub += ' | 요일: ${dowNames.join(",")}';
              }

              if (m.startAt != null && m.endAt != null) {
                final s = DateFormat('yyyy-MM-dd').format(m.startAt!.toDate());
                final e = DateFormat('yyyy-MM-dd').format(m.endAt!.toDate());
                sub += ' | 기간: $s ~ $e';
              }

              if (!m.active) sub += '  (비활성)';


              return ListTile(
                title: Text(m.name),
                subtitle: Text(sub),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: m.active ? '비활성화' : '활성화',
                      icon: Icon(m.active ? Icons.pause_circle : Icons.play_circle),
                      onPressed: () => _patchMedication(elderUid!, m.id, {'active': !m.active}),
                    ),
                    IconButton(
                      tooltip: '수정',
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final res = await _showMedicationDialog(
                          context,
                          initial: m,
                        );
                        if (res == null) return;
                        final updated = Medication(
                          id: m.id,
                          name: res['name'] as String,
                          times: (res['times'] as List).cast<String>(),
                          active: res['active'] as bool,
                          daysOfWeek: (res['daysOfWeek'] as List?)?.cast<int>(),
                          startAt: res['startAt'] as Timestamp?,
                          endAt: res['endAt'] as Timestamp?,
                        );
                        await _updateMedication(elderUid!, updated);
                      },
                    ),
                    IconButton(
                      tooltip: '삭제',
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('삭제할까요?'),
                            content: Text('"${m.name}" 항목을 삭제합니다.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _deleteMedication(elderUid!, m.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
