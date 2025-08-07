import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

import 'past_diary_screen.dart';

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;
  bool _isRecording = false;
  String _emotionResult = '😊 안정적인 상태입니다.';

  // 🔹 녹음 시작
  Future<void> _startRecording() async {
    await Permission.microphone.request();
    if (await Permission.microphone.isGranted) {
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/temp.wav';

      await _recorder.openRecorder();
      await _recorder.startRecorder(
        toFile: _audioPath,
        codec: Codec.pcm16WAV,
      );

      setState(() {
        _isRecording = true;
      });
    }
  }

  // 🔹 녹음 중지 + 서버 업로드
  Future<void> _stopRecordingAndSend() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();

    setState(() {
      _isRecording = false;
    });

    if (_audioPath != null) {
      await _uploadAudio(File(_audioPath!));
    }
  }

  // 🔹 음성 녹음 on/off
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  // 🔹 FastAPI 서버에 업로드
  Future<void> _uploadAudio(File audioFile) async {
    final uri = Uri.parse('http://10.0.2.2:8000/transcribe/'); // 필요시 IP 변경
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);
      setState(() {
        final existingText = _diaryController.text;
        final newText = data['text'];
        _diaryController.text =
        existingText.isEmpty ? newText : '$existingText\n$newText';
      });
    } else {
      print('❌ 서버 오류: ${response.statusCode}');
    }
  }

  // 🔹 간단 감정 분석
  void _analyzeEmotion() {
    String text = _diaryController.text;
    if (text.contains("우울") || text.contains("힘들어")) {
      _emotionResult = '😢 우울한 감정이 감지되었습니다.';
    } else if (text.contains("행복") || text.contains("좋아")) {
      _emotionResult = '😊 긍정적인 감정이 감지되었습니다.';
    } else {
      _emotionResult = '😐 중립적인 상태입니다.';
    }
    setState(() {});
  }

  // 🔹 Firestore에 저장
  void _saveDiary() async {
    final text = _diaryController.text.trim();
    if (text.isEmpty) return;

    _analyzeEmotion();

    try {
      await FirebaseFirestore.instance.collection('diaries').add({
        'text': text,
        'emotion': _emotionResult,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _diaryController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("일기가 저장되었습니다")),
      );
    } catch (e) {
      print("일기 저장 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("일기 저장에 실패했습니다")),
      );
    }
  }

  void _viewPastEntries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PastDiaryScreen()),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
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
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _diaryController,
                    maxLines: 7,
                    decoration: InputDecoration(
                      labelText: "오늘 하루 어땠나요?",
                      labelStyle:
                      TextStyle(fontSize: 16, color: Colors.grey[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                        label:
                        Text(_isRecording ? "녹음 중지" : "음성 녹음"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording
                              ? Colors.redAccent
                              : Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        _isRecording ? "녹음 중..." : "",
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // 감정 결과 표시
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveDiary,
                      icon: Icon(Icons.save),
                      label: Text("일기 저장하기"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
