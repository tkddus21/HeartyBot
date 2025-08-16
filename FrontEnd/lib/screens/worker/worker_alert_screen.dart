import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 이상 알림 데이터를 담을 모델 클래스
class EmotionAlert {
  final String elderName;
  final String reason; // AI 분석 결과
  final DateTime createdAt;

  EmotionAlert({
    required this.elderName,
    required this.reason,
    required this.createdAt,
  });
}

class WorkerAlertScreen extends StatefulWidget {
  final Elder? selectedElder;

  const WorkerAlertScreen({Key? key, this.selectedElder}) : super(key: key);

  @override
  _WorkerAlertScreenState createState() => _WorkerAlertScreenState();
}

class _WorkerAlertScreenState extends State<WorkerAlertScreen> {

  // 🔧 모든 담당 어르신의 '부정' 감정 일기를 불러오는 함수
  Future<List<EmotionAlert>> _fetchNegativeEmotionAlerts() async {
    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null) return [];

    // 1. 복지사 문서에서 담당 어르신 uid 목록 가져오기
    final workerDoc = await FirebaseFirestore.instance.collection('users').doc(workerUid).get();
    if (!workerDoc.exists || workerDoc.data()?['managed_elder_uids'] == null) {
      return [];
    }

    final List<dynamic> elderUids = workerDoc.data()!['managed_elder_uids'];
    if (elderUids.isEmpty) return [];

    List<EmotionAlert> allAlerts = [];

    // 2. 각 어르신별로 '부정' 감정 일기 조회
    for (String uid in elderUids) {
      final elderDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final elderName = elderDoc.data()?['name'] ?? '이름 없음';

      final diaryQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .where('emotion', isEqualTo: '부정') // '부정' 감정만 필터링
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in diaryQuery.docs) {
        final data = doc.data();
        allAlerts.add(EmotionAlert(
          elderName: elderName,
          reason: data['emotion_reason'] ?? '분석 결과 없음', // 🔧 AI 분석 결과
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
    }

    // 3. 모든 알림을 최신순으로 정렬
    allAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return allAlerts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmotionAlert>>(
      future: _fetchNegativeEmotionAlerts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("알림을 불러오는 중 오류가 발생했습니다."));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "감지된 이상 알림이 없습니다.",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          );
        }

        final alerts = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // FutureBuilder를 다시 실행하여 새로고침
          },
          child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                  title: Text(
                    "${alert.elderName} 어르신 - 부정 감지",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('M월 d일 HH:mm').format(alert.createdAt)}\nAI 분석: ${alert.reason}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // 🔧 일기 내용 대신 AI 분석 이유(reason)를 보여주는 팝업
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('${alert.elderName}님의 AI 분석 결과'),
                        content: SingleChildScrollView(
                          child: Text(alert.reason), // 일기 텍스트 대신 reason 표시
                        ),
                        actions: [
                          TextButton(
                            child: Text('닫기'),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
