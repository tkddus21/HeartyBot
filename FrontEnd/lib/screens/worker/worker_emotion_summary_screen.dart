import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 일기 데이터를 담을 모델 클래스
class DiaryEntry {
  final String text;
  final String emotion;
  final String reason;
  final DateTime createdAt;

  DiaryEntry({
    required this.text,
    required this.emotion,
    required this.reason,
    required this.createdAt,
  });

  // Firestore 데이터를 DiaryEntry 객체로 변환
  factory DiaryEntry.fromFirestore(Map<String, dynamic> data) {
    return DiaryEntry(
      text: data['text'] ?? '내용 없음',
      emotion: data['emotion'] ?? '미분석',
      reason: data['emotion_reason'] ?? '이유 없음',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class WorkerEmotionSummaryScreen extends StatefulWidget {
  // 🔧 부모 위젯으로부터 선택된 어르신 정보를 전달받음
  final Elder? selectedElder;

  const WorkerEmotionSummaryScreen({Key? key, this.selectedElder}) : super(key: key);

  @override
  _WorkerEmotionSummaryScreenState createState() => _WorkerEmotionSummaryScreenState();
}

class _WorkerEmotionSummaryScreenState extends State<WorkerEmotionSummaryScreen> {

  // 🔧 Firestore에서 일기 데이터를 불러오는 함수
  Stream<List<DiaryEntry>> _getDiaryStream() {
    if (widget.selectedElder == null) {
      return Stream.value([]); // 선택된 어르신이 없으면 빈 스트림 반환
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.selectedElder!.uid) // 선택된 어르신의 uid 사용
        .collection('diaries')
        .orderBy('createdAt', descending: true) // 최신순으로 정렬
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DiaryEntry.fromFirestore(doc.data()))
        .toList());
  }

  // 🔧 감정 아이콘을 반환하는 헬퍼 함수
  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case '긍정':
        return Icons.sentiment_very_satisfied;
      case '부정':
        return Icons.sentiment_very_dissatisfied;
      case '슬픔':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  // 🔧 감정 색상을 반환하는 헬퍼 함수
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case '긍정':
        return Colors.green;
      case '부정':
        return Colors.red;
      case '슬픔':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 선택된 어르신이 없으면 안내 메시지 표시
    if (widget.selectedElder == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "대시보드에서 분석할 어르신을 선택해주세요.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return StreamBuilder<List<DiaryEntry>>(
      stream: _getDiaryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text("데이터를 불러오는 중 오류가 발생했습니다.\n권한을 확인해주세요."));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("${widget.selectedElder!.name}님의 작성된 일기가 없습니다."));
        }

        final diaries = snapshot.data!;

        return ListView.builder(
          itemCount: diaries.length,
          itemBuilder: (context, index) {
            final entry = diaries[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  _getEmotionIcon(entry.emotion),
                  color: _getEmotionColor(entry.emotion),
                  size: 40,
                ),
                title: Text(
                  '${entry.emotion} (${DateFormat('M월 d일').format(entry.createdAt)})',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'AI 분석: ${entry.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  // 🔧 탭하면 AI 분석 이유 전체를 보여주는 팝업으로 변경
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('${DateFormat('yyyy년 M월 d일').format(entry.createdAt)}의 AI 분석'),
                      content: SingleChildScrollView(child: Text(entry.reason)), // 🔧 일기 내용(text) 대신 분석 이유(reason)를 표시
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
        );
      },
    );
  }
}
