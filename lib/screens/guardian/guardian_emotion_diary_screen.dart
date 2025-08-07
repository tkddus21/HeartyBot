import 'package:flutter/material.dart';

class GuardianEmotionDiaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> emotionSummary = [
    {"date": "2025-07-28", "emotion": "기쁨"},
    {"date": "2025-07-27", "emotion": "슬픔"},
    {"date": "2025-07-26", "emotion": "불안"},
  ];

  Color getEmotionColor(String emotion) {
    switch (emotion) {
      case "기쁨": return Colors.green;
      case "슬픔": return Colors.blue;
      case "불안": return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData getEmotionIcon(String emotion) {
    switch (emotion) {
      case "기쁨": return Icons.sentiment_satisfied;
      case "슬픔": return Icons.sentiment_dissatisfied;
      case "불안": return Icons.sentiment_neutral;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF6F5FC),
      child: ListView.builder(
        itemCount: emotionSummary.length,
        itemBuilder: (context, index) {
          final item = emotionSummary[index];
          return ListTile(
            leading: Icon(getEmotionIcon(item["emotion"]), color: getEmotionColor(item["emotion"])),
            title: Text(item["date"], style: TextStyle(color: Color(0xFF333333))),
            subtitle: Text("기분 상태: ${item["emotion"]}", style: TextStyle(color: Color(0xFF333333))),
            onTap: null, // 클릭 시 아무 동작 없음 (세부 보기 차단)
          );
        },
      ),
    );
  }
}
