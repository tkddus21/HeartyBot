// NOTE: This screen inlines Firestore queries so it works without lib/services/guardian_repository.dart.

// lib/screens/guardian_medication_screen.dart
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

Future<String?> _resolveElderUid() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final meData = me.data() ?? {};
  final cached = (meData['elderUid'] as String?)?.trim();
  if (cached != null && cached.isNotEmpty) return cached;

  final elderEmailRaw = (meData['elderEmail'] as String?)?.trim();
  if (elderEmailRaw == null || elderEmailRaw.isEmpty) return null;
  final elderEmail = elderEmailRaw.toLowerCase();

  final q = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: elderEmail)
      .limit(1)
      .get();

  if (q.docs.isEmpty) return null;
  final elderUid = q.docs.first.id;

  // cache
  await FirebaseFirestore.instance.collection('users').doc(uid).update({'elderUid': elderUid});
  return elderUid;
}


class GuardianMedicationScreen extends StatelessWidget {
  const GuardianMedicationScreen({super.key});

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchMedDocs(String elderUid) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('medication_logs');
    // Avoid requiring an index/field; sort by doc.id (yyyy-MM-dd) on client
    return col.snapshots().map((snap) {
      final docs = snap.docs.toList();
      docs.sort((a, b) => b.id.compareTo(a.id)); // desc
      return docs.take(14).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveElderUid(),
      builder: (context, uidSnap) {
        if (uidSnap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final elderUid = uidSnap.data;
        if (elderUid == null) {
          return const Center(child: Text('연결된 노인 계정을 찾을 수 없습니다.'));
        }

        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _watchMedDocs(elderUid),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!;
            if (docs.isEmpty) return const Center(child: Text('약 복용 기록이 없습니다.'));

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = docs[i];
                final data = d.data();
                final date = d.id; // yyyy-MM-dd
                final doses = data['doses'] as Map<String, dynamic>?;
                final taken = data['taken'] == true;

                if (doses != null && doses.isNotEmpty) {
                  final entries = doses.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...entries.map((e) {
                            final k = e.key;
                            final v = (e.value as Map?) ?? {};
                            final status = (v['status'] ?? 'pending') as String;
                            final ok = status == 'taken';
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(k),
                                Text(ok ? '✅ 복용' : '❌ 미복용'),
                              ],
                            );
                          })
                        ],
                      ),
                    ),
                  );
                } else {
                  return ListTile(
                    title: Text(date),
                    trailing: Text(taken ? '✅ 복용' : '❌ 미복용'),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
