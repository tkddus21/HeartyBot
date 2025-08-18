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
  await FirebaseFirestore.instance.collection('users').doc(uid).update({'elderUid': elderUid});
  return elderUid;
}

/// 날짜 유틸
DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
DateTime _todayEnd() {
  final s = _todayStart();
  return s.add(const Duration(hours: 23, minutes: 59, seconds: 59));
}
int _weekdayIndexKo(DateTime d) {
  // 0=일..6=토 (앱에서 쓰는 규약)
  return d.weekday % 7; // Mon=1..Sun=7 → 0..6 로 변환
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
Stream<QuerySnapshot<Map<String, dynamic>>> _watchLatestEmotion(String elderUid) {
  // emotion_logs 최신 1건
  return FirebaseFirestore.instance
      .collection('users').doc(elderUid)
      .collection('emotion_logs')
      .orderBy('date', descending: true)
      .limit(1)
      .snapshots();
}

/// 오늘 복용 로그 문서 (medication_logs/yyyy-MM-dd)
Stream<DocumentSnapshot<Map<String, dynamic>>> _watchTodayMedLog(String elderUid) {
  final id = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return FirebaseFirestore.instance
      .collection('users').doc(elderUid)
      .collection('medication_logs').doc(id)
      .snapshots();
}

/// 오늘 복용 예정 약(Plan): 조건에 맞는 medications (active, 기간 포함)
Stream<QuerySnapshot<Map<String, dynamic>>> _watchTodayMedPlans(String elderUid) {
  final start = Timestamp.fromDate(_todayStart());
  final end = Timestamp.fromDate(_todayEnd());
  // daysOfWeek는 클라이언트에서 필터링(빈 배열 허용 등 복잡 조건 때문)
  return FirebaseFirestore.instance
      .collection('users').doc(elderUid)
      .collection('medications')
      .where('active', isEqualTo: true)
      .where('startAt', isLessThanOrEqualTo: end)
      .where('endAt', isGreaterThanOrEqualTo: start)
      .limit(50)
      .snapshots();
}

/// 최근 "부정" 감정 일기(7일 이내, 최대 5개)
Stream<QuerySnapshot<Map<String, dynamic>>> _watchRecentNegativeDiaries(String elderUid) {
  final from = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
  // 서버 where 은 createdAt만, 감정은 클라이언트에서 필터(영/한 둘 다 가능)
  return FirebaseFirestore.instance
      .collection('users').doc(elderUid)
      .collection('diaries')
      .where('createdAt', isGreaterThanOrEqualTo: from)
      .orderBy('createdAt', descending: true)
      .limit(30)
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
            // ── 오늘의 기분
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
                        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── 오늘의 약 복용 (계획 + 진행도)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchTodayMedPlans(elderUid),
              builder: (context, planSnap) {
                final allPlans = planSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                // 요일 필터 (빈 배열 → 매일로 간주)
                final dow = _weekdayIndexKo(DateTime.now());
                final plans = allPlans.where((doc) {
                  final m = doc.data();
                  final dows = (m['daysOfWeek'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
                  return dows.isEmpty || dows.contains(dow);
                }).toList();

                // 전체 용량(오늘 예정 복용 횟수) 계산
                final int totalDoses = plans.fold<int>(0, (p, e) {
                  final times = (e.data()['times'] as List?) ?? const [];
                  return p + times.length;
                });

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _watchTodayMedLog(elderUid),
                  builder: (context, logSnap) {
                    final log = logSnap.data?.data();
                    int taken = 0;
                    if (log != null) {
                      // medication_logs/yyyy-MM-dd 구조 가정: { taken: bool?, doses: { "HH:mm": {status: "taken"|"missed"|...} } }
                      final doses = log['doses'] as Map<String, dynamic>?;
                      if (doses != null) {
                        for (final v in doses.values) {
                          final st = (v as Map?)?['status']?.toString();
                          if (st == 'taken') taken++;
                        }
                      } else if (log['taken'] == true) {
                        taken = totalDoses; // 단일 플래그로 모두 완료 처리되는 케이스
                      }
                    }

                    final progress = (totalDoses == 0) ? 0.0 : taken / totalDoses;
                    final ratioLabel = (totalDoses == 0) ? '오늘 일정 없음' : '$taken / $totalDoses';

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
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(ratioLabel),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0, 1),
                                minHeight: 10,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (plans.isEmpty)
                              const Text('오늘 복용 예정 약이 없습니다.')
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: plans.map((doc) {
                                  final m = doc.data();
                                  final name = (m['name'] ?? '').toString();
                                  final times = ((m['times'] as List?) ?? const [])
                                      .map((e) => e.toString())
                                      .toList()
                                    ..sort();
                                  // 각 시간별 상태 아이콘 표시
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Text(name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: times.map((t) {
                                              String statusIcon = '⏳';
                                              if (log != null && log['doses'] is Map<String, dynamic>) {
                                                final doses = log['doses'] as Map<String, dynamic>;
                                                final st = (doses[t] as Map?)?['status']?.toString();
                                                if (st == 'taken') statusIcon = '✅';
                                                else if (st == 'missed') statusIcon = '❌';
                                              }
                                              return Chip(
                                                label: Text('$t  $statusIcon'),
                                                backgroundColor: Colors.grey[100],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ── 최근 안전 알림(부정 감정 일기 감지)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchRecentNegativeDiaries(elderUid),
              builder: (context, negSnap) {
                final docs = (negSnap.data?.docs ?? []).where((e) {
                  final emo = (e.data()['emotion'] ?? '').toString();
                  return emo == '부정' ||
                      emo.toLowerCase() == 'sad' ||
                      emo.toLowerCase() == 'angry' ||
                      emo == '분노' || emo == '화남';
                }).take(5).toList();

                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('최근 안전 알림',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (docs.isEmpty)
                          const Text('최근 일주일 간 부정 감정 기록이 없습니다.')
                        else
                          ...docs.map((e) {
                            final d = e.data();
                            final ts = d['createdAt'] as Timestamp?;
                            final when = ts?.toDate() ?? DateTime.now();
                            final text = (d['text'] ?? '').toString();
                            final labelTime =
                                DateFormat('yyyy-MM-dd HH:mm').format(when);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
