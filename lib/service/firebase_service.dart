// firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 감정기록 저장
Future<void> saveEmotionLog({
  required String uid,
  required String date,
  required String text,
  required String emotion,
  required double score,
  required String emoji,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('emotion_logs')
      .doc(date)
      .set({
    'date': date,
    'text': text,
    'emotion': emotion,
    'score': score,
    'emoji': emoji,
  });
}
//감정 기록 출력
Stream<QuerySnapshot> getEmotionLogs(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('emotion_logs')
      .orderBy('date', descending: true)
      .snapshots();
}
//약 복용 저장
Future<void> saveMedicationLog({
  required String uid,
  required String date,
  required bool taken,
  required List<String> sideEffects,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('medication_logs')
      .doc(date)
      .set({
    'date': date,
    'taken': taken,
    'side_effects': sideEffects,
  });
}
//약 복용 기록 출력
Stream<QuerySnapshot> getMedicationLogs(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('medication_logs')
      .orderBy('date', descending: true)
      .snapshots();
}
//대화 기록 저장
Future<void> saveChatLog({
  required String uid,
  required DateTime timestamp,
  required String type, // 예: '회상대화', '일반대화'
  required String prompt,
  required String response,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chat_logs')
      .doc(timestamp.toIso8601String())
      .set({
    'timestamp': timestamp,
    'type': type,
    'prompt': prompt,
    'response': response,
  });
}
//대화 기록 출력
Stream<QuerySnapshot> getChatLogs(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chat_logs')
      .orderBy('timestamp', descending: true)
      .snapshots();
}
//경고 저장
Future<void> saveAlert({
  required String uid,
  required String alertType,
  required String sentTo,
  required DateTime timestamp,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('alerts')
      .add({
    'alert_type': alertType,
    'sent_to': sentTo,
    'timestamp': timestamp,
  });
}
//보고서 저장
Future<void> saveDailyReport({
  required String uid,
  required String date,
  required String summary,
  required String emoji,
  required String recommendation,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('reports')
      .doc(date)
      .set({
    'date': date,
    'summary': summary,
    'emoji': emoji,
    'recommendation': recommendation,
  });
}
//보고서 출력
Stream<QuerySnapshot> getReports(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('reports')
      .orderBy('date', descending: true)
      .snapshots();
}



