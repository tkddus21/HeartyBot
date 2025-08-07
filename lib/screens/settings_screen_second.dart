import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreenSecond extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreenSecond> {
  bool _notificationsEnabled = true;

  void _toggleNotification(bool value) {
    setState(() {
      _notificationsEnabled = value;
      // TODO: SharedPreferences 저장 또는 Firebase Firestore에 저장
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _deleteAccount() async {
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("계정 삭제 실패: 재로그인이 필요할 수 있어요.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F5FC),
      appBar: AppBar(
        title: Text("설정"),
        backgroundColor: Color(0xFF7B61FF),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text("알림 받기", style: TextStyle(color: Color(0xFF333333))),
            secondary: Icon(Icons.notifications),
            value: _notificationsEnabled,
            onChanged: _toggleNotification,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("로그아웃", style: TextStyle(color: Color(0xFF333333))),
            onTap: _logout,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text("계정 탈퇴", style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
