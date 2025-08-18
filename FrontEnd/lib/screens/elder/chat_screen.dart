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

/// ===== 날짜/문서 헬퍼 =====
String _todayId() => DateFormat('yyyy-MM-dd').format(DateTime.now());

DocumentReference<Map<String, dynamic>> _todayChatDoc() {
  final uid = FirebaseAuth.instance.currentUser!.uid; // 로그인 전제
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chats')
      .doc(_todayId());
}

/// ===== 메시지 저장(append) =====
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

/// ===== 오늘 채팅 스트림 =====
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

/// ===== just_audio 메모리 소스 =====
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

/// ===== 색상(라벤더 톤) =====
const _brandPurple = Color(0xFF9B8CF6); // 연보라
const _lightBg = Color(0xFFF7F6FD);     // 아주 옅은 보라빛 배경
const _border = Color(0x1A9B8CF6);      // 보라 10% 테두리

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
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
        debugPrint("TTS 서버 오류: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("TTS 네트워크 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final transcribedText = await _transcribeAudio(audioPath);
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
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '${tempDir.path}/audio.m4a',
        );
        setState(() {
          _isRecording = true;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한이 필요합니다.')),
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
    final userInput = textToSend ?? _controller.text.trim();
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

  // 사용자/봇 말풍선 하단 옵션 버튼
  Widget _buildMessageOptions(String text, bool isUser) {
    return Container(
      margin: isUser
          ? const EdgeInsets.only(right: 8, bottom: 4)
          : const EdgeInsets.only(left: 56, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isUser) ...[
            _OptionIcon(
              icon: Icons.edit,
              onTap: () => _controller.text = text,
            ),
            const SizedBox(width: 4),
            _OptionIcon(
              icon: Icons.refresh,
              onTap: () => _sendMessage(textToSend: text, playTts: true),
            ),
          ],
          if (!isUser) ...[
            _OptionIcon(
              icon: Icons.volume_up,
              onTap: () => _playBotTts(text),
            ),
          ],
        ],
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _lightBg), // 은은한 배경
        Scaffold(
          backgroundColor: Colors.transparent,
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final isUser = (m['role'] == 'user');
                        final text = (m['text'] ?? '').toString();

                        return Column(
                          crossAxisAlignment:
                          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            MessageBubble(text: text, isUser: isUser),
                            _buildMessageOptions(text, isUser),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              if (_isLoading)
                const LinearProgressIndicator(minHeight: 2),

              // 입력 바
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // 마이크 버튼
                      _SmallRoundBtn(
                        onPressed: _isLoading ? null : _handleMicButtonPressed,
                        bg: _isRecording ? Colors.red : _brandPurple,
                        icon: _isRecording ? Icons.stop : Icons.mic,
                      ),
                      const SizedBox(width: 8),

                      // 입력창
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(playTts: false),
                            decoration: const InputDecoration(
                              hintText: '메시지를 입력하세요',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 전송 버튼
                      _SmallRoundBtn(
                        onPressed: _isLoading ? null : () => _sendMessage(playTts: false),
                        bg: _brandPurple,
                        icon: Icons.send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 녹음 상태 표시(은은)
        if (_isRecording)
          Positioned(
            top: kToolbarHeight + 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0,2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                    SizedBox(width: 6),
                    Text('녹음 중…', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ===== 말풍선 =====
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
    // 사용자/봇 스타일
    final Color bg = isUser ? _brandPurple : Colors.white;
    final Color fg = isUser ? Colors.white : Colors.black87;
    final BorderRadius br = isUser
        ? const BorderRadius.only(
      topLeft: Radius.circular(14),
      topRight: Radius.circular(14),
      bottomLeft: Radius.circular(14),
      bottomRight: Radius.circular(4),
    )
        : const BorderRadius.only(
      topLeft: Radius.circular(14),
      topRight: Radius.circular(14),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(14),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundImage: AssetImage('assets/mascot2.jpg'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: br,
                border: isUser ? null : Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                text,
                style: TextStyle(color: fg, fontSize: 15.5, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== 말풍선 옵션 아이콘(작고 은은하게) =====
class _OptionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _OptionIcon({Key? key, required this.icon, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: Colors.black54),
      ),
    );
  }
}

/// ===== 작은 라운드 버튼(마이크/전송) =====
class _SmallRoundBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color bg;
  final IconData icon;
  const _SmallRoundBtn({
    Key? key,
    required this.onPressed,
    required this.bg,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? bg.withOpacity(0.5) : bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
