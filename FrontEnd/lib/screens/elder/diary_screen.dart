import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'past_diary_screen.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;
  bool _isRecording = false;

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  /// 🔹 감정 분석 (UI 표시 X, 저장만)
  String _analyzeEmotion(String text) {
    if (text.contains("우울") || text.contains("힘들어")) {
      return '슬픔';
    } else if (text.contains("행복") || text.contains("좋아")) {
      return '기쁨';
    } else {
      return '중립';
    }
  }

  /// 일기 저장 (Firestore) 
 void _saveDiary() async {
  final text = _diaryController.text.trim();
  if (text.isEmpty) return;

  final emotion = _analyzeEmotion(text);

  try {
    final user = await _ensureAuth();           // ✅ 로그인 보장
    final uid = user.uid;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final diaryRef = userDoc.collection('diaries').doc(); // auto id

    final batch = FirebaseFirestore.instance.batch();

    batch.set(diaryRef, {
      'text': text,
      'emotion': emotion,
      'createdAt': FieldValue.serverTimestamp(),  // ✅ createdAt로 통일
      'updatedAt': FieldValue.serverTimestamp(),
      // 'audioUrl': '...'(나중에 Storage 붙이면 여기)
      // 'tags': [],
    });

    // 선택: 유저 요약 필드 업데이트
    batch.set(
      userDoc,
      {
        'lastDiaryAt': FieldValue.serverTimestamp(),
        'diaryCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    _diaryController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("일기가 저장되었습니다")),
    );
  } catch (e) {
    debugPrint("일기 저장 실패: $e");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("저장 실패: $e")),
    );
  }
}

  Future<User> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user!;
    }
    return user!;
  }

  /// 🔹 녹음 시작/중지 토글
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    await Permission.microphone.request();
    if (await Permission.microphone.isGranted) {
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/temp.m4a';

      await _recorder.openRecorder();
      await _recorder.startRecorder(
        toFile: _audioPath,
        codec: Codec.aacMP4,
      );

      setState(() {
        _isRecording = true;
      });
    }
  }

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

  /// 🔹 FastAPI 서버에 음성 업로드
  Future<void> _uploadAudio(File audioFile) async {
    final uri = Uri.parse('http://10.0.2.2:8000/transcribe');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: MediaType('audio', 'mp4'),
      ));

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      debugPrint('HTTP ${response.statusCode}');
      debugPrint('BODY(len=${respStr.length}): ${respStr.substring(0, respStr.length.clamp(0, 200))}');

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
        return;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(respStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ JSON 파싱 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 응답 형식이 올바르지 않습니다.')),
        );
        return;
      }

      final newText = (data['text'] ?? '').toString();
      final before = _diaryController.text;
      final combined = before.isEmpty ? newText : '$before\n$newText';

      if (!mounted) return;
      setState(() {
        _diaryController.text = combined;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _diaryController.selection = TextSelection.fromPosition(
          TextPosition(offset: _diaryController.text.length),
        );
      });

    } catch (e) {
      debugPrint('❌ 업로드 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크/업로드 오류가 발생했습니다.')),
      );
    }
  }

  /// 🔹 이전 일기 보기 화면 이동
  void _viewPastEntries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PastDiaryScreen()),
    );
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
