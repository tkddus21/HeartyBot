
import 'package:flutter/material.dart';

class GuardianAlertScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF6F5FC),
      child: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.error, color: Color(0xFFFF6B6B)),
            title: Text("응답 없음 감지", style: TextStyle(color: Color(0xFF333333))),
            subtitle: Text("2025-07-28 08:30", style: TextStyle(color: Color(0xFF333333))),
          ),
          ListTile(
            leading: Icon(Icons.mood_bad, color: Color(0xFFFF6B6B)),
            title: Text("우울 반응 감지", style: TextStyle(color: Color(0xFF333333))),
            subtitle: Text("2025-07-27 22:15", style: TextStyle(color: Color(0xFF333333))),
          ),
        ],
      ),
    );
  }
}
