import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  // 🔧 FastAPI 서버로 챗봇 응답 요청하는 함수
  Future<String> _fetchBotResponse(String userInput) async {
    final url = Uri.parse('http://127.0.0.1:8000/chat'); // 서버 주소 바꿔도 됨
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_input": userInput,
          "medicine_time": false
        }),
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

  // 🔧 메시지 전송 + 챗봇 응답 저장
  void _sendMessage() async {
    String userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _isLoading = true;
      _controller.clear();
    });

    // 사용자 메시지 Firestore 저장
    await FirebaseFirestore.instance.collection('chats').add({
      'message': userInput,
      'userid': 'testUser', // 로그인 연동 전까지는 임시
      'createdAt': Timestamp.now(),
    });

    // 챗봇 응답 요청 및 저장
    String botReply = await _fetchBotResponse(userInput);
    await FirebaseFirestore.instance.collection('chats').add({
      'message': botReply,
      'userid': 'bot',
      'createdAt': Timestamp.now(),
    });

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
          // 🔄 Firestore에서 실시간 메시지 불러오기
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                return ListView(
                  children: docs.map((doc) {
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
                  }).toList(),
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

          // 🔽 입력창
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "메시지를 입력하세요",
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
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
