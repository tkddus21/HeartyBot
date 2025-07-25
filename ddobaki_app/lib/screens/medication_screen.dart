import 'package:flutter/material.dart';

class MedicationScreen extends StatefulWidget {
  @override
  _MedicationScreenState createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  List<Map<String, dynamic>> medications = [
    {
      'name': '고혈압약',
      'time': '08:00',
      'taken': false,
    },
    {
      'name': '혈당약',
      'time': '20:00',
      'taken': false,
    },
  ];

  bool notificationsEnabled = true;

  void _markAsTaken(int index) {
    setState(() {
      medications[index]['taken'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${medications[index]['name']} 복용 완료")),
    );
  }

  void _delayMedication(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${medications[index]['name']} 복용을 미뤘어요.")),
    );
  }

  void _toggleNotification(bool value) {
    setState(() {
      notificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("약 복용"),
        actions: [
          Row(
            children: [
              Text("알림", style: TextStyle(fontSize: 14)),
              Switch(
                value: notificationsEnabled,
                onChanged: _toggleNotification,
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: medications.length,
        itemBuilder: (context, index) {
          final med = medications[index];
          return Card(
            color: med['taken'] ? Colors.green[50] : null,
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(Icons.medication_liquid),
              title: Text(med['name']),
              subtitle: Text("복용 시간: ${med['time']}"),
              trailing: med['taken']
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _delayMedication(index),
                    child: Text("미루기"),
                  ),
                  ElevatedButton(
                    onPressed: () => _markAsTaken(index),
                    child: Text("복용"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
