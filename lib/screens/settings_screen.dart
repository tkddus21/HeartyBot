// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _chatStyle = '공손하게';
  TimeOfDay _alarmTime = TimeOfDay(hour: 8, minute: 0);
  TextEditingController _guardianPhoneController = TextEditingController();

  void _pickAlarmTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
    );
    if (picked != null) {
      setState(() {
        _alarmTime = picked;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _deleteAccount() {
    // TODO: Firebase 사용자 삭제 처리
    print("계정 탈퇴 요청");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("설정"),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // 챗봇 말투 설정
          ListTile(
            title: Text("챗봇 말투 설정"),
            subtitle: Text("현재: $_chatStyle"),
            trailing: DropdownButton<String>(
              value: _chatStyle,
              items: ['공손하게', '친구처럼'].map((style) {
                return DropdownMenuItem(
                  value: style,
                  child: Text(style),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _chatStyle = value!;
                });
              },
            ),
          ),
          Divider(),

          // 알림 시간 설정
          ListTile(
            title: Text("알림 시간 설정"),
            subtitle: Text("$_alarmTime 기준 알림"),
            trailing: IconButton(
              icon: Icon(Icons.schedule),
              onPressed: _pickAlarmTime,
            ),
          ),
          Divider(),

          // 보호자 전화번호 설정
          ListTile(
            title: Text("보호자 전화번호"),
            subtitle: TextField(
              controller: _guardianPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "010-1234-5678",
              ),
            ),
          ),
          Divider(),

          // 로그아웃
          ElevatedButton.icon(
            onPressed: _logout,
            icon: Icon(Icons.logout),
            label: Text("로그아웃"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
            ),
          ),
          SizedBox(height: 12),

          // 계정 탈퇴
          ElevatedButton.icon(
            onPressed: _deleteAccount,
            icon: Icon(Icons.delete),
            label: Text("계정 탈퇴"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}
