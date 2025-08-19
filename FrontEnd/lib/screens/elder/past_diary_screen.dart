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
  const PastDiaryScreen({super.key, this.showEmotion = false}); // ✅ 추가

  /// 노출 제어(노인: 기본 false, 보호자/복지사: true로 넘겨서 사용)
  final bool showEmotion; // ✅ 추가

  static final DateFormat _fmtDate = DateFormat('yyyy.MM.dd (E)', 'ko');
  static final DateFormat _fmtTime = DateFormat('HH:mm');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _diariesStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? {},
      toFirestore: (d, _) => d,
    )
        .snapshots();
  }

  /// createdAt 또는 문서 id(YYYY-MM-DD...) 에서 'yyyy-MM-dd' 키를 추출
  String _dateKeyOfDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();

    if (dt == null) {
      final m = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(doc.id);
      if (m != null) {
        try {
          dt = DateTime.parse(m.group(1)!);
        } catch (_) {}
      }
    }
    dt ??= DateTime.fromMillisecondsSinceEpoch(0);
    return DateFormat('yyyy-MM-dd').format(DateTime(dt.year, dt.month, dt.day));
  }

  DateTime _parseKey(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('이전 감정 일기'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _brandPurple,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _diariesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('기록된 일기가 없습니다.'));
          }

          // 1) 날짜별 그룹핑
          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
          for (final d in docs) {
            final key = _dateKeyOfDoc(d);
            (grouped[key] ??= []).add(d);
          }

          // 2) 날짜키 내림차순
          final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          // 3) 섹션화
          final List<_SectionItem> items = [];
          for (final key in keys) {
            final day = _parseKey(key);
            items.add(_SectionHeader(day));
            for (final doc in grouped[key]!) {
              items.add(_SectionEntry(doc));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              if (it is _SectionHeader) {
                return _DateHeader(label: _fmtDate.format(it.day));
              } else if (it is _SectionEntry) {
                return _DiaryTile(
                  doc: it.doc,
                  timeFormatter: _fmtTime,
                  showEmotion: showEmotion, // ✅ 여기서 전달
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

/// 섹션 타입
abstract class _SectionItem {}
class _SectionHeader extends _SectionItem {
  final DateTime day;
  _SectionHeader(this.day);
}
class _SectionEntry extends _SectionItem {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  _SectionEntry(this.doc);
}

/// 날짜 헤더
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일기 카드
class _DiaryTile extends StatelessWidget {
  const _DiaryTile({
    required this.doc,
    required this.timeFormatter,
    this.showEmotion = false, // ✅ 기본 숨김
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DateFormat timeFormatter;
  final bool showEmotion; // ✅ 추가

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final text = (m['text'] ?? '') as String;
    final emotion = (m['emotion'] ?? '') as String;
    final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
    final timeLabel = createdAt != null ? timeFormatter.format(createdAt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _brandPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book_rounded, color: _brandPurple, size: 20),
        ),
        title: Text(
          text.isEmpty ? '(내용 없음)' : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            if (timeLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(
                  timeLabel,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            // ✅ 노인 UI에서는 기본 false → 감정 뱃지 숨김
            if (showEmotion && emotion.isNotEmpty) _EmotionBadge(label: emotion),
          ],
        ),
        onTap: () {
          // 필요 시 상세 보기/편집 등
        },
      ),
    );
  }
}

class _EmotionBadge extends StatelessWidget {
  const _EmotionBadge({required this.label});
  final String label;

  Color _bgFor(String l) {
    if (l.contains('기쁨')) return const Color(0xFFE8F7E8);
    if (l.contains('슬픔')) return const Color(0xFFF3E8FF);
    if (l.contains('불안')) return const Color(0xFFFFF3E0);
    if (l.contains('화')) return const Color(0xFFFFEBEE);
    return const Color(0xFFEDE7F6);
  }

  Color _fgFor(String l) {
    if (l.contains('기쁨')) return const Color(0xFF2E7D32);
    if (l.contains('슬픔')) return const Color(0xFF6A1B9A);
    if (l.contains('불안')) return const Color(0xFFEF6C00);
    if (l.contains('화')) return const Color(0xFFC62828);
    return const Color(0xFF5E35B1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgFor(label),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, color: _fgFor(label), fontWeight: FontWeight.w700),
      ),
    );
  }
}
