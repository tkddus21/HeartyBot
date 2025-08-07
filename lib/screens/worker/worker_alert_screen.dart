import 'package:flutter/material.dart';

class WorkerAlertScreen extends StatelessWidget {
  final List<Map<String, String>> alerts = [
    {"name": "이영희", "alert": "응답 없음", "time": "2025-07-28 08:30"},
    {"name": "박노인", "alert": "우울 반응", "time": "2025-07-27 22:10"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final item = alerts[index];
        return ListTile(
          leading: Icon(Icons.warning, color: Colors.red),
          title: Text("${item['name']} 어르신", style: TextStyle(color: Color(0xFF333333))),
          subtitle: Text("${item['alert']} - ${item['time']}", style: TextStyle(color: Color(0xFF333333))),
        );
      },
    );
  }
}
