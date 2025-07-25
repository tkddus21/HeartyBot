import 'package:flutter/material.dart';

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  String _emotionResult = '😊 안정적인 상태입니다.';
  bool _isRecording = false;

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    // TODO: speech_to_text 연동 (추후)
  }

  void _analyzeEmotion() {
    String text = _diaryController.text;
    // 간단한 감정 분석 시뮬레이션
    if (text.contains("우울") || text.contains("힘들어")) {
      _emotionResult = '😢 우울한 감정이 감지되었습니다.';
    } else if (text.contains("행복") || text.contains("좋아")) {
      _emotionResult = '😊 긍정적인 감정이 감지되었습니다.';
    } else {
      _emotionResult = '😐 중립적인 상태입니다.';
    }

    setState(() {});
  }

  void _saveDiary() {
    final text = _diaryController.text.trim();
    if (text.isEmpty) return;

    _analyzeEmotion();

    // TODO: Firebase 저장 로직 추가
    print("일기 저장됨: $text");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("일기가 저장되었습니다")),
    );
  }

  void _viewPastEntries() {
    // TODO: 이전 일기 보기 화면으로 이동
    print("이전 일기 보기로 이동");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("감정 일기"),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _viewPastEntries,
            tooltip: '이전 일기 보기',
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [

            // 텍스트 입력창
            TextField(
              controller: _diaryController,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: "오늘 하루 어땠나요?",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // 음성 녹음 버튼
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                  label: Text(_isRecording ? "녹음 중지" : "음성 녹음"),
                ),
                SizedBox(width: 16),
                Text(
                  _isRecording ? "녹음 중..." : "",
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 감정 분석 결과
            Row(
              children: [
                Icon(Icons.insights, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  _emotionResult,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 저장 버튼
            ElevatedButton.icon(
              onPressed: _saveDiary,
              icon: Icon(Icons.save),
              label: Text("일기 저장하기"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

