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

    await FirebaseFirestore.instance.collection('chats').add({
      'message': userInput,
      'userid': 'testUser',
      'createdAt': Timestamp.now(),
    });

    String botReply = await _fetchBotResponse(userInput);
    await FirebaseFirestore.instance.collection('chats').add({
      'message': botReply,
      'userid': 'bot',
      'createdAt': Timestamp.now(),
    });

    if (playTts) {
      await _playBotTts(botReply);
    }

    setState(() {
      _isLoading = false;
    });
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                // 🔧 데이터가 업데이트 될 때마다 스크롤을 맨 아래로 이동시킵니다.
                _scrollToBottom();

                final docs = snapshot.data!.docs;

                return ListView.builder( // 🔧 ListView.builder로 변경
                  controller: _scrollController, // 🔧 스크롤 컨트롤러 연결
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final isUser = doc['userid'] == 'testUser';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(doc['message'] ?? ''),
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
