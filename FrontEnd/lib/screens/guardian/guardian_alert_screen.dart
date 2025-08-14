// NOTE: This screen inlines Firestore queries so it works without lib/services/guardian_repository.dart.

// lib/screens/guardian_alert_screen.dart
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


class GuardianAlertScreen extends StatelessWidget {
  const GuardianAlertScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchAlerts(String elderUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(50)
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

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _watchAlerts(elderUid),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('알림 기록이 없습니다.'));

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final type = (d['type'] ?? 'unknown').toString();
                final message = (d['message'] ?? '').toString();
                final ts = d['createdAt'] as Timestamp?;
                final when = ts?.toDate() ?? DateTime.now();
                final dt = '${when.year}-${when.month.toString().padLeft(2,'0')}-${when.day.toString().padLeft(2,'0')} '
                    '${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}';

                IconData icon; Color color;
                switch (type) {
                  case 'noResponse': icon = Icons.hearing_disabled; color = Colors.orange; break;
                  case 'fall': icon = Icons.emergency; color = Colors.red; break;
                  case 'sadness': icon = Icons.mood_bad; color = Colors.blueGrey; break;
                  default: icon = Icons.notifications; color = Colors.teal;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(message),
                  subtitle: Text(dt),
                );
              },
            );
          },
        );
      },
    );
  }
}
