import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 이상 알림 데이터를 담을 모델 클래스
class EmotionAlert {
  final String diaryId;
  final String elderUid;
  final String elderName;
  final String reason;
  final String diaryText;
  final DateTime createdAt;
  final String actionStatus;

  EmotionAlert({
    required this.diaryId,
    required this.elderUid,
    required this.elderName,
    required this.reason,
    required this.diaryText,
    required this.createdAt,
    this.actionStatus = '미확인',
  });
}

class WorkerAlertScreen extends StatefulWidget {
  // 🔧 home_screen_worker.dart와의 연결 오류를 해결하기 위해 selectedElder를 받도록 수정
  final Elder? selectedElder;

  const WorkerAlertScreen({Key? key, this.selectedElder}) : super(key: key);

  @override
  _WorkerAlertScreenState createState() => _WorkerAlertScreenState();
}

class _WorkerAlertScreenState extends State<WorkerAlertScreen> {

  Future<List<EmotionAlert>> _fetchNegativeEmotionAlerts() async {
    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null) return [];

    final workerDoc = await FirebaseFirestore.instance.collection('users').doc(workerUid).get();
    if (!workerDoc.exists || workerDoc.data()?['managed_elder_uids'] == null) {
      return [];
    }

    final List<dynamic> elderUids = workerDoc.data()!['managed_elder_uids'];
    if (elderUids.isEmpty) return [];

    List<EmotionAlert> allAlerts = [];

    for (String uid in elderUids) {
      final elderDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final elderName = elderDoc.data()?['name'] ?? '이름 없음';

      final diaryQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .where('emotion', isEqualTo: '부정')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in diaryQuery.docs) {
        final data = doc.data();
        allAlerts.add(EmotionAlert(
          diaryId: doc.id,
          elderUid: uid,
          elderName: elderName,
          reason: data['emotion_reason'] ?? '분석 결과 없음',
          diaryText: data['text'] ?? '일기 내용 없음',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          actionStatus: data['actionStatus'] ?? '미확인',
        ));
      }
    }

    allAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allAlerts;
  }

  // 후속 조치 기록을 위한 팝업 함수
  void _showActionDialog(EmotionAlert alert) {
    final actionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${alert.elderName}님 조치 기록'),
          content: TextField(
            controller: actionController,
            decoration: InputDecoration(
              hintText: '조치 내용을 입력하세요 (예: 전화 상담 완료)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('완료로 표시'),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(alert.elderUid)
                    .collection('diaries')
                    .doc(alert.diaryId)
                    .update({
                  'actionStatus': '조치 완료',
                  'actionNote': actionController.text.trim(),
                  'actionTakenBy': FirebaseAuth.instance.currentUser?.email,
                  'actionTakenAt': FieldValue.serverTimestamp(),
                });
                Navigator.of(context).pop();
                setState(() {}); // 화면 새로고침
              },
            ),
          ],
        );
      },
    );
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
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final isCompleted = alert.actionStatus == '조치 완료';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isCompleted ? Colors.grey.shade300 : null,
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                  title: Text(
                    "${alert.elderName} 님 - 부정 감지",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('M월 d일 HH:mm').format(alert.createdAt)}\nAI 분석: ${alert.reason}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: isCompleted
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(child: Text('조치하기'), onPressed: () => _showActionDialog(alert)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('${alert.elderName}님의 AI 분석 결과'),
                        content: SingleChildScrollView(child: Text(alert.reason)),
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
