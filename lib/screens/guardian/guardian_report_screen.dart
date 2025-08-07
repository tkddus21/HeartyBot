
import 'package:flutter/material.dart';

class GuardianReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF6F5FC),
      child: Center(
        child: Card(
          color: Colors.white,
          margin: EdgeInsets.all(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("오늘의 기분: 😊 기쁨", style: TextStyle(fontSize: 18, color: Color(0xFF333333))),
                SizedBox(height: 10),
                Text("약 복용: 완료", style: TextStyle(fontSize: 18, color: Color(0xFF333333))),
                SizedBox(height: 10),
                Text("AI 응답률: 정상", style: TextStyle(fontSize: 18, color: Color(0xFF333333))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
