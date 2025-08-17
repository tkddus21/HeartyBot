// lib/screens/guardian_medication_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// ====== 간단 입력 다이얼로그 ======
Future<Map<String, dynamic>?> _showMedicationDialog(
  BuildContext context, {
  Medication? initial,
}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final timesCtrl = TextEditingController(
    text: initial == null ? '' : initial.times.join(','),
  );
  bool active = initial?.active ?? true;

  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(initial == null ? '약 추가' : '약 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '약 이름'),
            ),
            TextField(
              controller: timesCtrl,
              decoration: const InputDecoration(
                labelText: '복용시간(쉼표로 구분, 예: 08:00,12:00,18:00)',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('활성화'),
              value: active,
              onChanged: (v) {
                active = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final times = timesCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (name.isEmpty || times.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이름과 시간은 필수입니다.')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'name': name,
                'times': times,
                'active': active,
              });
            },
            child: const Text('확인'),
          ),
        ],
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
              return ListTile(
                title: Text(m.name),
                subtitle: Text('시간: ${m.times.join(", ")}${m.active ? "" : "  (비활성)"}'),
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
                          daysOfWeek: m.daysOfWeek,
                          startAt: m.startAt,
                          endAt: m.endAt,
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
