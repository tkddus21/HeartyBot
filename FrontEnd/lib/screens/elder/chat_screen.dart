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
    'updatedAt': FieldValue.serverTimestamp(),
    'messages': FieldValue.arrayUnion([
      {
        'role': role,
        'text': text,
        'createdAt': Timestamp.now(),
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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _playBotTts(String textToSpeak) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final url = Uri.parse('http://10.0.2.2:8000/tts');
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": textToSpeak}),
      );

      if (res.statusCode == 200) {
        await _audioPlayer.setAudioSource(MyCustomSource(res.bodyBytes));
        _audioPlayer.play();
      } else {
        print("TTS 서버 오류: ${res.statusCode}");
      }
    } catch (e) {
      print("TTS 네트워크 오류: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
      await _appendChatMessage(role: 'user', text: userInput);
      final botReply = await _fetchBotResponse(userInput);
      await _appendChatMessage(role: 'bot', text: botReply);

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

  // 🔧 기능 버튼들을 보여주는 위젯
  Widget _buildMessageOptions(String text, bool isUser) {
    return Container(
      margin: isUser
          ? EdgeInsets.only(right: 8, bottom: 4)
          : EdgeInsets.only(left: 56, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isUser) ...[
            _OptionButton(icon: Icons.edit, onTap: () {
              _controller.text = text;
            }),
            SizedBox(width: 4),
            _OptionButton(icon: Icons.refresh, onTap: () {
              _sendMessage(textToSend: text, playTts: true);
            }),
          ],
          if (!isUser) ...[
            _OptionButton(icon: Icons.volume_up, onTap: () {
              _playBotTts(text);
            }),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isUser = (m['role'] == 'user');
                    final text = (m['text'] ?? '').toString();

                    return Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        MessageBubble(
                          text: text,
                          isUser: isUser,
                        ),
                        _buildMessageOptions(text, isUser),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).cardColor,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic, color: _isRecording ? Colors.red : Theme.of(context).iconTheme.color),
                    onPressed: _isLoading ? null : _handleMicButtonPressed,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "메시지를 입력하세요",
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (value) => _sendMessage(playTts: false),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _isLoading ? null : () => _sendMessage(playTts: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 말풍선 UI를 위한 별도의 위젯
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.isUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              child: Icon(Icons.support_agent),
              backgroundColor: Colors.grey.shade300,
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.green[100] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isUser ? Radius.circular(16) : Radius.circular(0),
                  bottomRight: isUser ? Radius.circular(0) : Radius.circular(16),
                ),
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔧 기능 버튼을 위한 작은 위젯 (라벨 제거)
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OptionButton({
    Key? key,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20), // 원형 터치 효과
      child: Padding(
        padding: const EdgeInsets.all(6), // 패딩 조정
        child: Icon(icon, size: 18, color: Colors.black54), // 아이콘 크기 조정
      ),
    );
  }
}
