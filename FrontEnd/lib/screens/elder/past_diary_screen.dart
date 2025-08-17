// past_diary_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PastDiaryScreen extends StatelessWidget {
  PastDiaryScreen({super.key});

  final _fmt = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    //  users/{uid}/diaries 에서 createdAt 내림차순
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이전 감정 일기')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('불러오기 오류: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('저장된 일기가 없습니다.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final text = (d['text'] ?? '') as String;
              final emotion = (d['emotion'] ?? '') as String;
              final ts = d['createdAt'];
              final created =
              (ts is Timestamp) ? ts.toDate() : null; // serverTimestamp 직후 null일 수 있음
              final dateStr = (created == null) ? '저장 중…' : _fmt.format(created);

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.message),
                  title: Text(
                    text.isEmpty ? '(내용 없음)' : text.split('\n').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(color: Colors.grey)),
                      if (emotion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('감정: $emotion'),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DiaryDetailScreen(diaryId: docs[i].id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

//상세보기
class DiaryDetailScreen extends StatelessWidget {
  final String diaryId;
  const DiaryDetailScreen({super.key, required this.diaryId});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('diaries')
        .doc(diaryId);

    return Scaffold(
      appBar: AppBar(title: const Text('일기 상세')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('존재하지 않는 일기입니다.'));
          }
          final d = snap.data!.data()!;
          final text = (d['text'] ?? '') as String;
          final emotion = (d['emotion'] ?? '') as String;
          final ts = d['createdAt'];
          final created =
          (ts is Timestamp) ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(created),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                if (emotion.isNotEmpty)
                  Text('감정: $emotion', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(text.isEmpty ? '(내용 없음)' : text),
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
