// past_diary_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastDiaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('이전 감정 일기'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('diaries')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('저장된 일기가 없습니다.'));
          }

          final diaryEntries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: diaryEntries.length,
            itemBuilder: (context, index) {
              final entry = diaryEntries[index];
              final text = entry['text'] ?? '';
              final timestamp = entry['timestamp']?.toDate();
              final dateStr = timestamp != null
                  ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}'
                  : '날짜 없음';

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  title: Text(text),
                  subtitle: Text(dateStr),
                  leading: Icon(Icons.bookmark_border),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
