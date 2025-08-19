// lib/screens/guardian_medication_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// ====== 모델 ======
class Medication {
  final String id;
  final String name;
  final List<String> times;
  final bool active;
  final List<dynamic>? daysOfWeek; // 0..6
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

  Map<String, dynamic> toCreateMap() => {
    'name': name,
    'times': times,
    'active': active,
    if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
    if (startAt != null) 'startAt': startAt,
    if (endAt != null) 'endAt': endAt,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    'times': times,
    'active': active,
    if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
    if (startAt != null) 'startAt': startAt,
    if (endAt != null) 'endAt': endAt,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// ====== Firestore 접근 ======
Future<String?> _resolveElderUid() async {
  final guardianUid = FirebaseAuth.instance.currentUser?.uid;
  if (guardianUid == null) return null;

  final meSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(guardianUid)
      .get(const GetOptions(source: Source.server));
  final me = meSnap.data();
  if (me == null) return null;

  final elderUid = (me['elderUid'] as String?);
  if (elderUid != null && elderUid.isNotEmpty) return elderUid;

  final elderEmail = ((me['elderEmail'] as String?) ?? '').trim().toLowerCase();
  if (elderEmail.isEmpty) return null;

  final idxSnap = await FirebaseFirestore.instance
      .collection('email_index')
      .doc(elderEmail)
      .get(const GetOptions(source: Source.server));

  return (idxSnap.data()?['uid'] as String?);
}

CollectionReference<Map<String, dynamic>> _medsCol(String elderUid) =>
    FirebaseFirestore.instance.collection('users').doc(elderUid).collection('medications');

Stream<List<Medication>> _watchMedications(String elderUid) => _medsCol(elderUid)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((qs) => qs.docs.map(Medication.fromDoc).toList());

Future<void> _createMedication(String elderUid, Medication med) async =>
    _medsCol(elderUid).add(med.toCreateMap());

Future<void> _updateMedication(String elderUid, Medication med) async =>
    _medsCol(elderUid).doc(med.id).update(med.toUpdateMap());

Future<void> _patchMedication(String elderUid, String medId, Map<String, dynamic> patch) async =>
    _medsCol(elderUid).doc(medId).update({...patch, 'updatedAt': FieldValue.serverTimestamp()});

Future<void> _deleteMedication(String elderUid, String medId) async =>
    _medsCol(elderUid).doc(medId).delete();

/// ====== 표시 유틸 ======
String _fmtDate(DateTime? d) => d == null ? '선택 안됨' : DateFormat('yyyy-MM-dd').format(d);

String _fmtTimeOfDay(TimeOfDay t) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
  return DateFormat('HH:mm').format(dt);
}

String _fmtDays(List<dynamic>? dows) {
  if (dows == null || dows.isEmpty) return '매일';
  const labels = ['일', '월', '화', '수', '목', '금', '토'];
  return dows.map((e) => labels[(e as num).toInt()]).join(', ');
}

String _compactTimes(List<String> times) {
  if (times.isEmpty) return '시간 없음';
  if (times.length <= 3) return times.join(' · ');
  return '${times.take(2).join(' · ')} 외 ${times.length - 2}';
}

/// ====== 입력 다이얼로그(추가/수정) ======
Future<Map<String, dynamic>?> _showMedicationDialog(
    BuildContext context, {
      Medication? initial,
    }) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final List<String> times = [...(initial?.times ?? const <String>[])];
  bool active = initial?.active ?? true;

  final Set<int> dows = {
    ...(initial?.daysOfWeek?.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 0) ??
        const <int>[]),
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

  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(initial == null ? '약 추가' : '약 수정'),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '약 이름'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('복용 시간', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('시간 추가'),
                        onPressed: () async {
                          final picked =
                          await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked == null) return;
                          final t = _fmtTimeOfDay(picked);
                          if (!times.contains(t)) {
                            setState(() {
                              times.add(t);
                              times.sort();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (times.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('아직 추가된 시간이 없습니다.'),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: times
                        .map((t) => Chip(
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(t),
                      onDeleted: () => setState(() => times.remove(t)),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('활성화'),
                    value: active,
                    onChanged: (v) => setState(() => active = v),

                    // ✅ 색상 적용 (ON = 민트, OFF = 회색)
                    activeColor: const Color(0xFF4CAF93),        // ON 상태: Thumb
                    activeTrackColor: const Color(0xFFB2DFDB),   // ON 상태: Track
                    inactiveThumbColor: const Color(0xFFBDBDBD), // OFF 상태: Thumb
                    inactiveTrackColor: const Color(0xFFE0E0E0), // OFF 상태: Track
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('요일 선택', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final selected = dows.contains(i);
                      return FilterChip(
                        label: Text(dowLabels[i]),
                        selected: selected,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (v) => setState(() => v ? dows.add(i) : dows.remove(i)),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('복용 시작일: ${_fmtDate(startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      await pickStart();
                      setState(() {});
                    },
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
                child: const Text('확인'),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty || times.isEmpty || startDate == null || endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('약 이름/시간/기간을 모두 입력해 주세요.')),
                    );
                    return;
                  }
                  final startTs = Timestamp.fromDate(
                      DateTime(startDate!.year, startDate!.month, startDate!.day));
                  final endTs = Timestamp.fromDate(
                      DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59));
                  Navigator.pop(ctx, {
                    'name': name,
                    'times': times,
                    'active': active,
                    'daysOfWeek': dows.toList()..sort(),
                    'startAt': startTs,
                    'endAt': endTs,
                  });
                },
              ),
            ],
          );
        },
      );
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
  String? elderName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = await _resolveElderUid();
      String? name;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get();
        name = (doc.data()?['name'] as String?)?.trim();
      }
      setState(() {
        elderUid = uid;
        elderName = name; // ✅ 저장
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

  Future<void> _openActionSheet(Medication m) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: Colors.deepPurple, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(m.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow(label: '시간', value: m.times.isEmpty ? '없음' : m.times.join(' · ')),
              _InfoRow(
                label: '기간',
                value: (m.startAt != null && m.endAt != null)
                    ? '${DateFormat('yyyy-MM-dd').format(m.startAt!.toDate())} ~ ${DateFormat('yyyy-MM-dd').format(m.endAt!.toDate())}'
                    : '설정 없음',
              ),
              _InfoRow(label: '요일', value: _fmtDays(m.daysOfWeek)),
              _InfoRow(label: '상태', value: m.active ? '활성' : '비활성'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('수정'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res = await _showMedicationDialog(context, initial: m);
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('삭제'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('삭제할까요?'),
                            content: Text('"${m.name}" 항목을 삭제합니다.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('취소')),
                              ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('삭제')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _deleteMedication(elderUid!, m.id);
                          if (context.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ],
          ),
        );
      },
    );
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
      floatingActionButton: FloatingActionButton.small(
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

          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 섹션 타이틀 (아이콘 + 텍스트)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.fact_check, color: Colors.deepPurple, size: 20), // 앞에 아이콘
                      const SizedBox(width: 6),
                      const Text(
                        '오늘의 복약 현황',
                        style: TextStyle(
                          fontWeight: FontWeight.w700, // 진하게
                          fontSize: 18,               // 폰트 줄이기 (원래 18~20 정도였다면 ↓)
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),


                // 리스트 카드
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0x14000000)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      itemCount: meds.length,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60, endIndent: 12),
                      itemBuilder: (context, i) {
                        final m = meds[i];
                        return ListTile(
                          dense: true,
                          visualDensity:
                          const VisualDensity(horizontal: -2, vertical: -2),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          onLongPress: () => _openActionSheet(m),
                          leading: const Icon(Icons.medication_liquid,
                              size: 22, color: Colors.deepPurple),
                          title: Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _compactTimes(m.times),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                            trailing: ActionChip(
                              avatar: Icon(
                                m.active ? Icons.check_circle : Icons.pause_circle_filled,
                                size: 18,
                                color: m.active ? const Color(0xFF673AB7) : Colors.grey,
                              ),
                              label: Text(
                                m.active ? '활성' : '중지',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: m.active ? const Color(0xFF673AB7) : Colors.grey,
                                ),
                              ),
                              backgroundColor: m.active ? const Color(0xFFD1C4E9) : const Color(0xFFE0E0E0),
                              onPressed: () => _patchMedication(elderUid!, m.id, {'active': !m.active}),
                            )
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

  }
}

/// 하단시트 정보 행
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 52, child: Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 6),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
