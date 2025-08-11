import 'package:flutter/material.dart';

class WorkerEmotionSummaryScreen extends StatelessWidget {
  final List<Map<String, String>> summaries = [
    {"name": "김철수", "emotion": "기쁨"},
    {"name": "이영희", "emotion": "슬픔"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final item = summaries[index];
        return ListTile(
          leading: Icon(Icons.insert_emoticon),
          title: Text("${item['name']} 어르신", style: TextStyle(color: Color(0xFF333333))),
          subtitle: Text("최근 감정 상태: ${item['emotion']}", style: TextStyle(color: Color(0xFF333333))),
        );
      },
    );
  }
}
