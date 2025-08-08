// import 'package:flutter/material.dart';
// import 'dart:io';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert'; // JSON 응답 처리
//
// class DiaryScreen extends StatefulWidget {
//   @override
//   _DiaryScreenState createState() => _DiaryScreenState();
// }
//
// class _DiaryScreenState extends State<DiaryScreen> {
//   final TextEditingController _diaryController = TextEditingController();
//   String _emotionResult = '😊 안정적인 상태입니다.';
//   bool _isRecording = false;
//
//   Future<void> _toggleRecording() async {
//     if (_isRecording) {
//       await _stopRecordingAndSend();
//     } else {
//       await _startRecording();
//     }
//   }
//
//
//   void _analyzeEmotion() {
//     String text = _diaryController.text;
//     // 간단한 감정 분석 시뮬레이션
//     if (text.contains("우울") || text.contains("힘들어")) {
//       _emotionResult = '😢 우울한 감정이 감지되었습니다.';
//     } else if (text.contains("행복") || text.contains("좋아")) {
//       _emotionResult = '😊 긍정적인 감정이 감지되었습니다.';
//     } else {
//       _emotionResult = '😐 중립적인 상태입니다.';
//     }
//
//     setState(() {});
//   }
//
//   void _saveDiary() {
//     final text = _diaryController.text.trim();
//     if (text.isEmpty) return;
//
//     _analyzeEmotion();
//
//     // TODO: Firebase 저장 로직 추가
//     print("일기 저장됨: $text");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("일기가 저장되었습니다")),
//     );
//   }
//
//   void _viewPastEntries() {
//     // TODO: 이전 일기 보기 화면으로 이동
//     print("이전 일기 보기로 이동");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("감정 일기"),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.history),
//             onPressed: _viewPastEntries,
//             tooltip: '이전 일기 보기',
//           )
//         ],
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           children: [
//
//             // 텍스트 입력창
//             TextField(
//               controller: _diaryController,
//               maxLines: 7,
//               decoration: InputDecoration(
//                 labelText: "오늘 하루 어땠나요?",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             SizedBox(height: 16),
//
//             // 음성 녹음 버튼
//             Row(
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _toggleRecording,
//                   icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
//                   label: Text(_isRecording ? "녹음 중지" : "음성 녹음"),
//                 ),
//                 SizedBox(width: 16),
//                 Text(
//                   _isRecording ? "녹음 중..." : "",
//                   style: TextStyle(color: Colors.red),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//
//             // 감정 분석 결과
//             Row(
//               children: [
//                 Icon(Icons.insights, color: Colors.purple),
//                 SizedBox(width: 8),
//                 Text(
//                   _emotionResult,
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//
//             // 저장 버튼
//             ElevatedButton.icon(
//               onPressed: _saveDiary,
//               icon: Icon(Icons.save),
//               label: Text("일기 저장하기"),
//               style: ElevatedButton.styleFrom(
//                 minimumSize: Size(double.infinity, 50),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   String? _audioPath;
//
//   Future<void> _startRecording() async {
//     await Permission.microphone.request();
//     if (await Permission.microphone.isGranted) {
//       final dir = await getTemporaryDirectory();
//       _audioPath = '${dir.path}/temp.wav';
//
//       await _recorder.openRecorder();
//       await _recorder.startRecorder(
//         toFile: _audioPath,
//         codec: Codec.pcm16WAV,
//       );
//
//       setState(() {
//         _isRecording = true;
//       });
//     }
//   }
//
//   Future<void> _stopRecordingAndSend() async {
//     await _recorder.stopRecorder();
//     await _recorder.closeRecorder();
//
//     setState(() {
//       _isRecording = false;
//     });
//
//     if (_audioPath != null) {
//       await _uploadAudio(File(_audioPath!));
//     }
//   }
//
//   Future<void> _uploadAudio(File audioFile) async {
//     final uri = Uri.parse('http://10.0.2.2:8000/transcribe/'); // PC IP 주소로 변경
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));
//
//     final response = await request.send();
//
//     if (response.statusCode == 200) {
//       final respStr = await response.stream.bytesToString();
//       final data = jsonDecode(respStr);
//       setState(() {
//         final existingText = _diaryController.text;
//         final newText = data['text'];
//         _diaryController.text = existingText.isEmpty
//             ? newText
//             : '$existingText\n$newText';
//       });
//     } else {
//       print('❌ 서버 오류: ${response.statusCode}');
//     }
//   }
//
// }
//

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isRecording = false;
  String _emotionResult = '';
  String _emoji = '';
  double _score = 0;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _recorder.openRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    await Permission.microphone.request();
    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/temp.wav';

    await _recorder.startRecorder(
      toFile: _audioPath,
      codec: Codec.pcm16WAV,
    );

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndAnalyze() async {
    await _recorder.stopRecorder();
    setState(() => _isRecording = false);

    if (_audioPath == null) return;

    final uri = Uri.parse('http://10.0.2.2:8000/transcribe/');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', _audioPath!));

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);
      final text = data['text'] ?? '';

      setState(() {
        _diaryController.text += '\n$text';
      });

      _analyzeEmotion(text);
    }
  }

  void _analyzeEmotion(String text) {
    if (text.contains("우울") || text.contains("힘들")) {
      _emotionResult = '우울함';
      _emoji = '😢';
      _score = 0.8;
    } else if (text.contains("좋아") || text.contains("행복")) {
      _emotionResult = '행복함';
      _emoji = '😊';
      _score = 0.9;
    } else {
      _emotionResult = '중립';
      _emoji = '😐';
      _score = 0.5;
    }

    setState(() {}); // 감정 결과 UI 업데이트
  }

  Future<void> _saveDiary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('emotion_logs')
        .doc(date)
        .set({
      'date': date,
      'text': _diaryController.text,
      'emotion': _emotionResult,
      'score': _score,
      'emoji': _emoji,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("일기가 저장되었습니다.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("감정 일기")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _diaryController,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: "오늘 하루 어땠나요?",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_isRecording) {
                      await _stopRecordingAndAnalyze();
                    } else {
                      await _startRecording();
                    }
                  },
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
            Row(
              children: [
                Text("감정 분석 결과: $_emoji $_emotionResult"),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveDiary,
              child: Text("일기 저장하기"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            )
          ],
        ),
      ),
    );
  }
}
