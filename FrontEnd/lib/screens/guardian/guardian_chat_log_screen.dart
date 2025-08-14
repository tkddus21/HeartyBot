// NOTE: This screen inlines Firestore queries so it works without lib/services/guardian_repository.dart.

// lib/screens/guardian_chat_log_screen.dart
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


class GuardianChatLogScreen extends StatelessWidget {
  const GuardianChatLogScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchChats(String elderUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(elderUid)
        .collection('chat_logs')
        .orderBy('createdAt', descending: true)
        .limit(100)
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
          stream: _watchChats(elderUid),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('대화 기록이 없습니다.'));

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final role = (d['role'] ?? 'assistant').toString();
                final content = (d['content'] ?? '').toString();
                final ts = d['createdAt'] as Timestamp?;
                final when = ts?.toDate() ?? DateTime.now();
                final time = '${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}';

                return Align(
                  alignment: role == 'user' ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: role == 'user' ? Colors.grey.shade200 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role == 'user' ? '사용자' : 'AI', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(content),
                        const SizedBox(height: 4),
                        Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
