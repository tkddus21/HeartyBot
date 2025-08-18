// NOTE: This screen inlines Firestore queries so it works without lib/services/guardian_repository.dart.
// lib/screens/guardian_report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// 보호자 → 노인 elderUid 해석
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
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'elderUid': elderUid});
  return elderUid;
}

/// 날짜 유틸
String _todayId() => DateFormat('yyyy-MM-dd').format(DateTime.now());
DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
DateTime _todayEnd() {
  final s = _todayStart();
  return s.add(const Duration(hours: 23, minutes: 59, seconds: 59));
}

/// 감정 → 이모지/색
const _emojiMap = {
  '긍정': '😊', '부정': '😢', '중립': '😐',
  'happy': '😊', 'joy': '😄', 'excited': '🤩',
  'sad': '😢', 'angry': '😠', 'fear': '😨',
  'neutral': '😐', 'surprised': '😮', 'tired': '🥱',
};
Color _emotionColor(String e) {
  switch (e) {
    case '긍정':
    case 'happy':
    case 'joy':
    case 'excited':
      return Colors.green;
    case '부정':
    case 'sad':
    case 'angry':
    case 'fear':
      return Colors.red;
    default:
      return Colors.amber; // 중립
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Firestore watchers

/// 오늘 최신 기분 1건 (emotion_logs)
Stream<QuerySnapshot<Map<String, dynamic>>> _watchLatestEmotion(String elderUid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(elderUid)
      .collection('emotion_logs')
      .orderBy('date', descending: true)
      .limit(1)
      .snapshots();
}

/// 오늘 복용 체크리스트 (days/{yyyy-MM-dd}/doses)
Stream<QuerySnapshot<Map<String, dynamic>>> _watchTodayDoses(String elderUid) {
  final dayId = _todayId();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(elderUid)
      .collection('days')
      .doc(dayId)
      .collection('doses')
      .orderBy('scheduledAt')
      .snapshots();
}

/// 최근 7일 중 부정 감정 일기
Stream<QuerySnapshot<Map<String, dynamic>>> _watchRecentDiaries(String elderUid) {
  final from = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
  return FirebaseFirestore.instance
      .collection('users')
      .doc(elderUid)
      .collection('diaries')
      .where('createdAt', isGreaterThanOrEqualTo: from)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();
}

/// ─────────────────────────────────────────────────────────────────────────
/// 화면
class GuardianReportScreen extends StatelessWidget {
  const GuardianReportScreen({super.key});

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

        return ListView(
          children: [
            /// ── 오늘의 기분
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchLatestEmotion(elderUid),
              builder: (context, emoSnap) {
                final has = emoSnap.hasData && emoSnap.data!.docs.isNotEmpty;
                String emoji = '🙂';
                String label = '데이터 없음';
                if (has) {
                  final d = emoSnap.data!.docs.first.data();
                  final em = (d['emotion'] ?? '').toString();
                  final emEmoji = (d['emoji'] ?? '').toString();
                  emoji = emEmoji.isNotEmpty ? emEmoji : (_emojiMap[em] ?? '🙂');
                  label = em.isEmpty ? '중립' : em;
                }
                final color = _emotionColor(label);

                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        const Text('오늘의 기분',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(label,
                            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),

            /// ── 오늘의 약 복용 (days/{yyyy-MM-dd}/doses 기반, 진행률 + 리스트)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchTodayDoses(elderUid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final docs = snap.data?.docs
                    ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final total = docs.length;
                final taken =
                    docs.where((d) => (d.data()['status'] == 'taken')).length;
                final progress = total == 0 ? 0.0 : taken / total;
                final ratioLabel = total == 0 ? '오늘 일정 없음' : '$taken / $total';

                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('오늘의 약 복용',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(ratioLabel),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (docs.isEmpty)
                          const Text('오늘 복용할 약이 없습니다.')
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final data = docs[i].data();
                              final medName = (data['medName'] ?? '') as String;
                              final status = (data['status'] ?? 'pending') as String;
                              final isTaken = status == 'taken';
                              final sched =
                              (data['scheduledAt'] as Timestamp?)?.toDate();
                              final label = sched != null
                                  ? DateFormat('HH:mm').format(sched)
                                  : '-';

                              final overdue = !isTaken &&
                                  sched != null &&
                                  DateTime.now().isAfter(
                                      sched.add(const Duration(minutes: 30)));

                              String statusIcon = '⏳';
                              if (isTaken) {
                                statusIcon = '✅';
                              } else if (overdue) {
                                statusIcon = '❌';
                              }

                              return ListTile(
                                leading: Icon(
                                  isTaken
                                      ? Icons.check_circle
                                      : (overdue
                                      ? Icons.error
                                      : Icons.schedule),
                                  color: isTaken
                                      ? Colors.green
                                      : (overdue
                                      ? Colors.redAccent
                                      : Colors.amber),
                                ),
                                title: Text(medName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: overdue
                                    ? const Text('예정 시간 경과',
                                    style:
                                    TextStyle(color: Colors.redAccent))
                                    : null,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(statusIcon,
                                        style:
                                        const TextStyle(fontSize: 16)),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            /// ── 최근 안전 알림 (최근 7일 중 '부정' 감정 일기 안내)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchRecentDiaries(elderUid),
              builder: (context, negSnap) {
                final docs = (negSnap.data?.docs ?? []).where((e) {
                  final emo = (e.data()['emotion'] ?? '').toString();
                  final k = emo.toLowerCase();
                  return emo == '부정' ||
                      k == 'sad' ||
                      k == 'angry' ||
                      emo == '분노' ||
                      emo == '화남';
                }).take(5).toList();

                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('최근 안전 알림',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (docs.isEmpty)
                          const Text('최근 일주일 간 부정 감정 기록이 없습니다.')
                        else
                          ...docs.map((e) {
                            final d = e.data();
                            final ts = d['createdAt'] as Timestamp?;
                            final when =
                                ts?.toDate() ?? DateTime.now();
                            final text =
                            (d['text'] ?? '').toString();
                            final labelTime = DateFormat('yyyy-MM-dd HH:mm')
                                .format(when);
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('⚠️ '),
                                  Expanded(
                                    child: Text(
                                      '$labelTime  부정 감정 기록 감지\n$text',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
