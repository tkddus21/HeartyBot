// lib/screens/guardian_emotion_diary_screen.dart
// NOTE: users/{elderUid}/diaries/{doc} with fields: createdAt, text, emotion, updatedAt

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// ── elderUid 해석 (보호자 -> 노인)
Future<String?> _resolveElderUid() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final me = await FirebaseFirestore.instance.collection('users').doc(uid)
      .get(const GetOptions(source: Source.server));
  final data = me.data() ?? {};

  final cached = (data['elderUid'] as String?)?.trim();
  if (cached != null && cached.isNotEmpty) return cached;

  final elderEmail = (data['elderEmail'] as String?)?.trim().toLowerCase();
  if (elderEmail == null || elderEmail.isEmpty) return null;

  final q = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: elderEmail)
      .limit(1)
      .get(const GetOptions(source: Source.server));
  if (q.docs.isEmpty) return null;

  final elderUid = q.docs.first.id;
  await FirebaseFirestore.instance.collection('users').doc(uid)
      .update({'elderUid': elderUid});
  return elderUid;
}

/// ── 감정 매핑(영/한 지원)
const _emojiMap = {
  // EN
  'happy': '😊', 'joy': '😄', 'excited': '🤩', 'neutral': '😐',
  'sad': '😢', 'angry': '😠', 'fear': '😨', 'surprised': '😮', 'tired': '🥱',
  // KR
  '기쁨': '😄', '행복': '😊', '설렘': '🤩', '중립': '😐',
  '슬픔': '😢', '화남': '😠', '분노': '😠', '두려움': '😨', '놀람': '😮', '피곤': '🥱',
};

Color _emotionColor(String e) {
  final k = e.toLowerCase();
  if (['happy','joy','excited','기쁨','행복','설렘'].contains(k)) return Colors.orange;
  if (['sad','슬픔'].contains(k)) return Colors.blue;
  if (['angry',' 화남','분노'].contains(k)) return Colors.red;
  if (['fear','두려움'].contains(k)) return Colors.deepPurple;
  if (['surprised','놀람'].contains(k)) return Colors.teal;
  if (['tired','피곤'].contains(k)) return Colors.brown;
  return Colors.grey;
}

String _dateLabel(DateTime d) => DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(d);
String _timeLabel(DateTime d) => DateFormat('HH:mm').format(d);

class GuardianEmotionDiaryScreen extends StatefulWidget {
  const GuardianEmotionDiaryScreen({super.key});
  @override
  State<GuardianEmotionDiaryScreen> createState() => _GuardianEmotionDiaryScreenState();
}

class _GuardianEmotionDiaryScreenState extends State<GuardianEmotionDiaryScreen> {
  String? _elderUid;
  bool _loading = true;

  String _range = '7d';        // '7d' | '30d' | 'all'
  String _emotion = 'all';     // 'all' or specific(영/한 어떤 값이든)

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await _resolveElderUid();
    setState(() { _elderUid = uid; _loading = false; });
  }

  Query<Map<String, dynamic>> _query(String elderUid) {
    final col = FirebaseFirestore.instance
        .collection('users').doc(elderUid).collection('diaries');

    DateTime? from;
    if (_range == '7d') from = DateTime.now().subtract(const Duration(days: 7));
    if (_range == '30d') from = DateTime.now().subtract(const Duration(days: 30));

    Query<Map<String, dynamic>> q = col;
    if (from != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    // 감정 필터는 영/한이 섞일 수 있으니 클라이언트 필터로 처리 (서버 where 생략)
    return q.orderBy('createdAt', descending: true).limit(200);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_elderUid == null) return const Center(child: Text('연결된 노인 계정을 찾지 못했습니다.'));

    return Column(
      children: [
        _FilterBar(
          range: _range,
          emotion: _emotion,
          onChanged: (r, e) => setState(() { _range = r; _emotion = e; }),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query(_elderUid!).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final raw = snap.data!.docs.map((d) {
                final m = d.data();
                final ts = m['createdAt'] as Timestamp?;
                return _DiaryEntry(
                  id: d.id,
                  when: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
                  text: (m['text'] ?? '').toString(),
                  emotion: (m['emotion'] ?? 'neutral').toString(),
                );
              }).toList();

              // 감정 클라이언트 필터
              final list = (_emotion == 'all')
                  ? raw
                  : raw.where((e) => e.emotion == _emotion).toList();

              if (list.isEmpty) return const Center(child: Text('표시할 일기가 없습니다.'));

              // 날짜별 그룹
              final sections = <_DaySection>[];
              _DaySection? cur;
              for (final e in list) {
                final key = DateTime(e.when.year, e.when.month, e.when.day);
                if (cur == null || cur.dayKey != key) {
                  cur = _DaySection(key, []);
                  sections.add(cur);
                }
                cur.entries.add(e);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sections.length,
                itemBuilder: (_, i) => _DaySectionWidget(section: sections[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ── 모델
class _DiaryEntry {
  final String id;
  final DateTime when;
  final String text;
  final String emotion;
  _DiaryEntry({required this.id, required this.when, required this.text, required this.emotion});
}

class _DaySection {
  final DateTime dayKey;
  final List<_DiaryEntry> entries;
  _DaySection(this.dayKey, this.entries);
}

/// ── UI
class _DaySectionWidget extends StatelessWidget {
  final _DaySection section;
  const _DaySectionWidget({required this.section});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(_dateLabel(section.dayKey),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        ...section.entries.map((e) => _DiaryCard(entry: e)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final _DiaryEntry entry;
  const _DiaryCard({required this.entry});
  @override
  Widget build(BuildContext context) {
    final emoji = _emojiMap[entry.emotion] ?? _emojiMap[entry.emotion.toLowerCase()] ?? '🙂';
    final circle = _emotionCircle(entry.emotion); // 🟢🔴🟡
    final color = _emotionColor(entry.emotion);
    final time = _timeLabel(entry.when);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailDialog(context, entry, emoji, color),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(height: 4),
                  Text(circle, style: const TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(entry.emotion, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text(time, style: TextStyle(color: Colors.grey[600])),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      entry.text.isEmpty ? '내용 없음' : entry.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이모티콘 아래 붙일 원형 심볼 매핑
String _emotionCircle(String e) {
  final k = e.trim(); // 혹시 공백 대비
  if (k == '긍정') return '🟢';
  if (k == '부정') return '🔴';
  if (k == '중립') return '🟡';
  return '⚪'; // 혹시 모르는 예외 처리
}



Future<void> _showDetailDialog(BuildContext context, _DiaryEntry e, String emoji, Color color) async {
  final dateFull = DateFormat('yyyy-MM-dd HH:mm', 'ko_KR').format(e.when);
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(e.emotion, style: TextStyle(color: color)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dateFull, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          Text(e.text.isEmpty ? '내용 없음' : e.text),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    ),
  );
}

/// 상단 필터 바
class _FilterBar extends StatelessWidget {
  final String range; // '7d' | '30d' | 'all'
  final String emotion; // 'all' or label
  final void Function(String range, String emotion) onChanged;
  const _FilterBar({required this.range, required this.emotion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // 감정 후보(영/한 혼용)
    const emotions = [
      'all','happy','joy','excited','neutral','sad','angry','fear','surprised','tired',
      '기쁨','행복','설렘','중립','슬픔','화남','분노','두려움','놀람','피곤'
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          DropdownButton<String>(
            value: range,
            onChanged: (v) => onChanged(v ?? '7d', emotion),
            items: const [
              DropdownMenuItem(value: '7d', child: Text('최근 7일')),
              DropdownMenuItem(value: '30d', child: Text('최근 30일')),
              DropdownMenuItem(value: 'all', child: Text('전체')),
            ],
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: emotion,
            onChanged: (v) => onChanged(range, v ?? 'all'),
            items: emotions.map((e) {
              final label = e == 'all' ? '전체 감정' : e;
              return DropdownMenuItem(value: e, child: Text(label));
            }).toList(),
          ),
        ],
      ),
    );
  }
}
