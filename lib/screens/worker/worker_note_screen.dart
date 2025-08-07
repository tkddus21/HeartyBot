import 'package:flutter/material.dart';

class WorkerNoteScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("오늘의 관찰 메모", style: TextStyle(fontSize: 18, color: Color(0xFF333333))),
          SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: "예: 김철수 어르신 - 복약 독려 필요",
              border: OutlineInputBorder(),
              fillColor: Colors.white,
              filled: true,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // 저장 처리
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("메모가 저장되었습니다.")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7B61FF),
              foregroundColor: Colors.white,
            ),
            child: Text("저장"),
          ),
        ],
      ),
    );
  }
}
