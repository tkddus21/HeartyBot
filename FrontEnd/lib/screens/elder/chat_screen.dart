import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

//// 오늘 날짜/문서 레퍼런스 헬퍼 
String _todayId() => DateFormat('yyyy-MM-dd').format(DateTime.now());

DocumentReference<Map<String, dynamic>> _todayChatDoc() {
  final uid = FirebaseAuth.instance.currentUser!.uid; //로그인 전제
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chats')
      .doc(_todayId());
}

//// 메시지 저장 함수 (배열 append)
Future<void> _appendChatMessage({
  required String role, // 'user' or 'bot'
  required String text,
}) async {
  final doc = _todayChatDoc();
  await doc.set({
    'date': _todayId(),
    // 최상위에서는 serverTimestamp 사용 가능
    'updatedAt': FieldValue.serverTimestamp(),
    // arrayUnion 내부에서는 serverTimestamp 사용 불가 → Timestamp.now()로 대체
    'messages': FieldValue.arrayUnion([
      {
        'role': role,
        'text': text,
        'createdAt': Timestamp.now(), // Timestamp.now로 변경
      }
    ]),
  }, SetOptions(merge: true));
}


////오늘 채팅 스트림 (배열 >> List<Map>로 변환)
Stream<List<Map<String, dynamic>>> _todayChatStream() {
  return _todayChatDoc().snapshots().map((snap) {
    if (!snap.exists) return <Map<String, dynamic>>[];
    final data = snap.data()!;
    final list = List<Map<String, dynamic>>.from(data['messages'] ?? []);
    // createdAt 기준 정렬(서버 타임스탬프가 동일해도 안전하게)
    list.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta is Timestamp && tb is Timestamp) {
        return ta.compareTo(tb);
      }
      return 0;
    });
    return list;
  });
}


// just_audio가 메모리의 오디오 데이터를 재생하기 위해 필요한 헬퍼 클래스
class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: (end ?? bytes.length) - (start ?? 0),
      offset: start ?? 0,
      stream: Stream.value(bytes.sublist(start ?? 0, end ?? bytes.length)),
      contentType: 'audio/mpeg',
    );
  }
}


class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // 🔧 스크롤 컨트롤러 생성
  bool _isLoading = false;

  late AudioRecorder _audioRecorder;
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose(); // 🔧 스크롤 컨트롤러 정리
    super.dispose();
  }

  // 🔧 스크롤을 맨 아래로 즉시 이동시키는 함수
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // 챗봇의 텍스트 응답을 음성으로 재생하는 함수
  Future<void> _playBotTts(String textToSpeak) async {
    final url = Uri.parse('http://10.0.2.2:8000/chat-tts');
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_input": textToSpeak, "medicine_time": false}),
      );

      if (res.statusCode == 200) {
        await _audioPlayer.setAudioSource(MyCustomSource(res.bodyBytes));
        await _audioPlayer.play();
      } else {
        print("TTS 서버 오류: ${res.statusCode}");
      }
    } catch (e) {
      print("TTS 네트워크 오류: $e");
    }
  }

  Future<String> _transcribeAudio(String audioPath) async {
    final url = Uri.parse('http://10.0.2.2:8000/transcribe');
    try {
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['text'] ?? "음성 인식 결과가 없습니다.";
      } else {
        return "음성 인식 서버 오류: ${res.statusCode}";
      }
    } catch (e) {
      return "음성 인식 네트워크 오류: $e";
    }
  }

  Future<void> _handleMicButtonPressed() async {
    if (_isRecording) {
      final audioPath = await _audioRecorder.stop();
      if (audioPath != null) {
        setState(() {
          _isRecording = false;
          _isLoading = true;
        });
        String transcribedText = await _transcribeAudio(audioPath);
        if (transcribedText.isNotEmpty) {
          _sendMessage(textToSend: transcribedText, playTts: true);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } else {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        Directory tempDir = await getTemporaryDirectory();
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: '${tempDir.path}/audio.m4a');
        setState(() {
          _isRecording = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이크 권한이 필요합니다.')),
        );
      }
    }
  }


  Future<String> _fetchBotResponse(String userInput) async {
    final url = Uri.parse('http://10.0.2.2:8000/chat');
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_input": userInput, "medicine_time": false}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['response'] ?? "서버 응답이 없습니다.";
      } else {
        return "서버 오류: ${res.statusCode}";
      }
    } catch (e) {
      return "네트워크 오류: $e";
    }
  }

  void _sendMessage({String? textToSend, bool playTts = false}) async {
    String userInput = textToSend ?? _controller.text.trim();
    if (userInput.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _controller.clear();
    });

    try {
      // 1) 유저 메시지 저장
      await _appendChatMessage(role: 'user', text: userInput);

      // 2) 서버에서 답변 받기
      final botReply = await _fetchBotResponse(userInput);

      // 3) 봇 메시지 저장
      await _appendChatMessage(role: 'bot', text: botReply);

      // 4) (옵션) 봇 음성 재생 -> 앞으로 만들어가야함.
      if (playTts) {
        await _playBotTts(botReply);
      }
    } catch (e) {
      debugPrint('채팅 저장/응답 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅 처리 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI 채팅"),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _todayChatStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                // 데이터 들어온 뒤 스크롤 맨 아래
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isUser = (m['role'] == 'user');
                    final text = (m['text'] ?? '').toString();

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 🔧 마이크 버튼을 왼쪽으로 이동
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  onPressed: _isLoading ? null : _handleMicButtonPressed,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: "메시지를 입력하세요"),
                  ),
                ),
                // 🔧 전송 버튼은 오른쪽에 그대로 둡니다.
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isLoading ? null : () => _sendMessage(playTts: false),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
