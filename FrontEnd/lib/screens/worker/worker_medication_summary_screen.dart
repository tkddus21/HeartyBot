import 'package:flutter/material.dart';

class WorkerMedicationSummaryScreen extends StatelessWidget {
  final List<Map<String, String>> meds = [
    {"name": "김철수", "taken": "✅"},
    {"name": "이영희", "taken": "❌"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: meds.length,
      itemBuilder: (context, index) {
        final item = meds[index];
        return ListTile(
          leading: Icon(Icons.medication),
          title: Text("${item['name']} 어르신", style: TextStyle(color: Color(0xFF333333))),
          subtitle: Text("오늘 복약: ${item['taken']}", style: TextStyle(color: Color(0xFF333333))),
        );
      },
    );
  }
}
