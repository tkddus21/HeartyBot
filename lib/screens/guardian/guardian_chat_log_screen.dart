import 'package:flutter/material.dart';

class GuardianChatLogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF6F5FC),
      child: Center(
        child: Card(
          margin: EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("오늘의 대화 요약", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                SizedBox(height: 20),
                Text("응답률: 90%", style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
                SizedBox(height: 8),
                Text("긍정 반응: 😊 60%", style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
                Text("부정 반응: 😟 15%", style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
                Text("중립 반응: 😐 25%", style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
