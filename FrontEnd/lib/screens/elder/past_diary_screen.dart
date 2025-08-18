// past_diary_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// 공통 색상 (라벤더 톤)
const _brandPurple = Color(0xFF9B8CF6);
const _lightBg = Color(0xFFF7F6FD);
const _border = Color(0x1A9B8CF6); // 10% 보라

class PastDiaryScreen extends StatelessWidget {
  PastDiaryScreen({super.key});

  final _fmt = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // users/{uid}/diaries 에서 createdAt 내림차순
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _lightBg),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('이전 감정 일기'),
            centerTitle: true,
            elevation: 0.5,
            backgroundColor: Colors.white,
            foregroundColor: _brandPurple,
          ),
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final text = (d['text'] ?? '') as String;
                  final emotion = (d['emotion'] ?? '') as String;
                  final ts = d['createdAt'];
                  final created = (ts is Timestamp) ? ts.toDate() : null; // 저장 직후 null 가능
                  final dateStr = (created == null) ? '저장 중…' : _fmt.format(created);

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DiaryDetailScreen(diaryId: docs[i].id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          // 아이콘 박스
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _brandPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_note, color: _brandPurple, size: 20),
                          ),
                          const SizedBox(width: 10),
                          // 본문
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 첫 줄 프리뷰
                                Text(
                                  text.isEmpty ? '(내용 없음)' : text.split('\n').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      dateStr,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    if (emotion.isNotEmpty)
                                      _EmotionChip(label: emotion),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: Colors.black38),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 상세보기
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

    return Stack(
      children: [
        Container(color: _lightBg),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('일기 상세'),
            centerTitle: true,
            elevation: 0.5,
            backgroundColor: Colors.white,
            foregroundColor: _brandPurple,
          ),
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
              final created = (ts is Timestamp)
                  ? ts.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 메타
                    Row(
                      children: [
                        const Icon(Icons.event_note, color: _brandPurple, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(created),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const Spacer(),
                        if (emotion.isNotEmpty) _EmotionChip(label: emotion),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 본문 카드
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: SingleChildScrollView(
                          child: Text(
                            text.isEmpty ? '(내용 없음)' : text,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 감정 배지(칩)
class _EmotionChip extends StatelessWidget {
  final String label;
  const _EmotionChip({required this.label});

  Color _bgFor(String l) {
    // 간단한 감정별 톤 (없으면 기본)
    final s = l.trim();
    if (s.contains('기쁨')) return const Color(0xFFE6F6E6);
    if (s.contains('슬픔')) return const Color(0xFFF3E8FF);
    if (s.contains('불안') || s.contains('걱정')) return const Color(0xFFFFF4E5);
    if (s.contains('화') || s.contains('분노')) return const Color(0xFFFFEAEA);
    return const Color(0xFFEFEFFD); // 라이트 라벤더
  }

  Color _fgFor(String l) {
    final s = l.trim();
    if (s.contains('기쁨')) return const Color(0xFF1B5E20);
    if (s.contains('슬픔')) return const Color(0xFF6A1B9A);
    if (s.contains('불안') || s.contains('걱정')) return const Color(0xFF8B5E00);
    if (s.contains('화') || s.contains('분노')) return const Color(0xFFB71C1C);
    return _brandPurple;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgFor(label),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, color: _fgFor(label))),
    );
  }
}
