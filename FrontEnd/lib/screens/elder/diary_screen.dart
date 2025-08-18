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

// ----- Colors (부드러운 라벤더 톤) -----
const _brandPurple = Color(0xFF9B8CF6); // 연보라
const _lightBg = Color(0xFFF7F6FD);     // 아주 옅은 보라빛 배경
const _border = Color(0x1A9B8CF6);      // 보라 10% (1A=10%)

// ======================================
class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;
  bool _isRecording = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  // ---------------- Emotion API ----------------
  Future<Map<String, String>> _fetchEmotionAnalysis(String text) async {
    final url = Uri.parse('http://10.0.2.2:8000/emotion'); // 에뮬레이터용
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_input": text}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return {
          'emotion': data['emotion'] ?? '중립',
          'reason': data['reason'] ?? '분석 불가',
        };
      } else {
        return {'emotion': '오류', 'reason': '서버 오류: ${res.statusCode}'};
      }
    } catch (e) {
      return {'emotion': '오류', 'reason': '네트워크 오류: $e'};
    }
  }

  // ---------------- Save Diary ----------------
  void _saveDiary() async {
    final text = _diaryController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emotionData = await _fetchEmotionAnalysis(text);
      final emotion = emotionData['emotion'];
      final reason = emotionData['reason'];

      final user = await _ensureAuth();
      final uid = user.uid;

      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final diaryRef = userDoc.collection('diaries').doc();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(diaryRef, {
        'text': text,
        'emotion': emotion,
        'emotion_reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(userDoc, {
        'lastDiaryAt': FieldValue.serverTimestamp(),
        'diaryCount': FieldValue.increment(1),
      });
      await batch.commit();

      _diaryController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일기가 저장되었습니다')),
      );
    } catch (e) {
      debugPrint("일기 저장 실패: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<User> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user!;
    }
    return user;
  }

  // ---------------- Recording ----------------
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

      setState(() => _isRecording = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다.')),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    setState(() => _isRecording = false);

    if (_audioPath != null) {
      await _uploadAudio(File(_audioPath!));
    }
  }

  // ---------------- Upload Audio ----------------
  Future<void> _uploadAudio(File audioFile) async {
    setState(() => _isLoading = true);
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
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
        return;
      }
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      final newText = (data['text'] ?? '').toString();
      final before = _diaryController.text;
      final combined = before.isEmpty ? newText : '$before\n$newText';
      if (!mounted) return;
      setState(() {
        _diaryController.text = combined;
      });
    } catch (e) {
      debugPrint('업로드 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크/업로드 오류가 발생했습니다.')),
// ignore: use_build_context_synchronously
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- History ----------------
  void _viewPastEntries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PastDiaryScreen()),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 은은한 배경
        Container(color: _lightBg),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('감정 일기'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: _brandPurple,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '이전 일기 보기',
                onPressed: _viewPastEntries,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀 (컴팩트)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Text(
                    '오늘의 감정 기록',
                    style: TextStyle(
                      color: _brandPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),

                // 입력 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.edit_note, color: _brandPurple, size: 20),
                          SizedBox(width: 4),
                          Text('내용 입력',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _diaryController,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                        decoration: InputDecoration(
                          hintText: '오늘 하루를 편하게 기록해보세요.',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                            BorderSide(color: _brandPurple.withOpacity(0.7), width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 음성 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.mic, color: _brandPurple, size: 18),
                          SizedBox(width: 4),
                          Text('음성 입력',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _toggleRecording,
                              icon: Icon(
                                _isRecording ? Icons.mic_off : Icons.mic,
                                size: 18,
                              ),
                              label: Text(_isRecording ? '중지' : '녹음'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                textStyle: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_isRecording)
                            const Text('녹음 중…',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '버튼을 누르고 말하면 텍스트로 변환됩니다.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 하단 저장 버튼(컴팩트)
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveDiary,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('저장',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 로딩 오버레이 (은은)
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.08),
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
      ],
    );
  }
}

// ----- 공통 카드: 패딩/그림자 축소로 컴팩트하게 -----
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
