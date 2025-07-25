import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = []; // {'role': 'user' or 'bot', 'text': '...'}

  void _sendMessage() {
    String userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userInput});
      _messages.add({'role': 'bot', 'text': _mockBotResponse(userInput)});
      _controller.clear();
    });
  }

  String _mockBotResponse(String input) {
    // 간단한 감정 반응 시뮬레이션
    if (input.contains("우울")) {
      return "요즘 많이 힘드셨군요. 제가 항상 곁에 있어요. 보호자에게 상태를 알릴까요?";
    } else if (input.contains("행복")) {
      return "행복한 하루를 보내고 계시다니 정말 기뻐요!";
    }
    return "말씀 감사합니다. 더 이야기해볼까요?";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI 챗봇"),
      ),
      body: Column(
        children: [

          // 메시지 목록
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message['text'] ?? ''),
                  ),
                );
              },
            ),
          ),

          Divider(),

          // 감정 분석 결과 예시 (간단히 노출)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.insights, color: Colors.purple),
                SizedBox(width: 8),
                Text("감정 상태: 😊 안정", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),

          // 입력창 + 전송
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.mic),
                  onPressed: () {
                    // 음성 입력 기능 연결 예정
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "말을 입력하거나 음성으로 말해주세요",
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
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


