// NOTE: This screen inlines Firestore queries so it works without lib/services/guardian_repository.dart.

// lib/screens/guardian_report_screen.dart
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


class GuardianReportScreen extends StatelessWidget {
  const GuardianReportScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchLatestEmotion(String elderUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('emotion_logs')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchTodayMed(String elderUid) {
    final id = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('medication_logs')
        .doc(id)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchRecentAlerts(String elderUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
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

        return Column(
          children: [
            // 오늘의 기분
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchLatestEmotion(elderUid),
              builder: (context, emoSnap) {
                final has = emoSnap.hasData && emoSnap.data!.docs.isNotEmpty;
                final d = has ? emoSnap.data!.docs.first.data() : null;
                final latestLabel = has
                    ? '${(d!['emoji'] ?? '').toString()} ${(d['emotion'] ?? '').toString()}'
                    : '데이터 없음';
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('오늘의 기분', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(latestLabel),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 오늘의 약
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _watchTodayMed(elderUid),
              builder: (context, medSnap) {
                final exists = medSnap.data?.exists == true;
                String label = '기록 없음';
                if (exists) {
                  final data = medSnap.data!.data()!;
                  final doses = data['doses'] as Map<String, dynamic>?;
                  final taken = data['taken'] == true;
                  final ok = taken || (doses?.values.any((v) => ((v as Map?)?['status']) == 'taken') ?? false);
                  label = ok ? '✅ 완료' : '❌ 미복용';
                }
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('오늘의 약 복용', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(label),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 최근 알림
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _watchRecentAlerts(elderUid),
                builder: (context, alertSnap) {
                  final docs = alertSnap.data?.docs ?? [];
                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('최근 안전 알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (docs.isEmpty) const Text('알림 없음'),
                          ...docs.map((e) {
                            final d = e.data();
                            return Text('• ${(d['type'] ?? '').toString()} - ${(d['message'] ?? '').toString()}');
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
