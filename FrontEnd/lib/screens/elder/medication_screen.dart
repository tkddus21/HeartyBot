// medication_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MedicationScreen extends StatelessWidget {
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _markAsTaken(DocumentReference docRef) async {
    try {
      await docRef.update({'taken': true});
    } catch (e) {
      print("복용 상태 업데이트 실패: $e");
    }
  }

  void _goToAddPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MedicationAddScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("약 복용 리스트"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _goToAddPage(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('등록된 약이 없습니다.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final med = doc.data() as Map<String, dynamic>;
              final isToday = med['startDate'] != null && med['endDate'] != null &&
                  today.compareTo(med['startDate']) >= 0 && today.compareTo(med['endDate']) <= 0;

              if (!isToday) return SizedBox.shrink();

              return Card(
                child: ListTile(
                  title: Text(med['name'] ?? ''),
                  subtitle: Text("${med['time']} / ${med['startDate']} ~ ${med['endDate']}"),
                  trailing: (med['taken'] ?? false)
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                    onPressed: () => _markAsTaken(doc.reference),
                    child: Text("복용"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MedicationAddScreen extends StatefulWidget {
  @override
  _MedicationAddScreenState createState() => _MedicationAddScreenState();
}

class _MedicationAddScreenState extends State<MedicationAddScreen> {
  final _nameController = TextEditingController();
  TimeOfDay? _selectedTime;
  DateTime? _startDate;
  DateTime? _endDate;

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _addMedication() async {
    final name = _nameController.text.trim();
    final time = _selectedTime != null ? _formatTime(_selectedTime!) : '';
    final startDate = _startDate != null ? _formatDate(_startDate!) : '';
    final endDate = _endDate != null ? _formatDate(_endDate!) : '';

    if (name.isNotEmpty && time.isNotEmpty && startDate.isNotEmpty && endDate.isNotEmpty) {
      final medication = {
        'name': name,
        'time': time,
        'startDate': startDate,
        'endDate': endDate,
        'taken': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance.collection('medications').add(medication);
        Navigator.pop(context);
      } catch (e) {
        print("저장 오류: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("저장에 실패했습니다")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("약 추가하기")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '약 이름',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              title: Text("복용 시간: ${_selectedTime != null ? _formatTime(_selectedTime!) : '선택 안됨'}"),
              trailing: Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            ListTile(
              title: Text("복용 시작일: ${_startDate != null ? _formatDate(_startDate!) : '선택 안됨'}"),
              trailing: Icon(Icons.calendar_today),
              onTap: _pickStartDate,
            ),
            ListTile(
              title: Text("복용 종료일: ${_endDate != null ? _formatDate(_endDate!) : '선택 안됨'}"),
              trailing: Icon(Icons.calendar_today),
              onTap: _pickEndDate,
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addMedication,
              child: Text("약 추가하기"),
            ),
          ],
        ),
      ),
    );
  }
}
