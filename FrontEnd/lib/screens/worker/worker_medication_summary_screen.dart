import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 약 정보를 담을 모델 클래스
class Medication {
  final String name;
  final String time; // Firestore에는 times 배열로 되어있지만, 여기서는 간단히 첫 번째 시간만 표시
  final bool taken;
  final DateTime startDate;
  final DateTime endDate;

  Medication({
    required this.name,
    required this.time,
    required this.taken,
    required this.startDate,
    required this.endDate,
  });

  // 🔧 Firestore 데이터를 Medication 객체로 변환하는 로직 수정
  factory Medication.fromFirestore(Map<String, dynamic> data) {
    // times 필드가 배열인지 확인하고, 비어있지 않으면 첫 번째 값을 사용
    String displayTime = '시간 미정';
    if (data['times'] is List && (data['times'] as List).isNotEmpty) {
      displayTime = (data['times'] as List).first.toString();
    }

    return Medication(
      name: data['name'] ?? '이름 없음',
      time: displayTime,
      // 'status' 필드에 따라 taken 여부 결정 (예시: 'completed'면 true)
      taken: data['status'] == 'completed',
      // 🔧 'startAt'과 'endAt' 필드를 사용하고, Timestamp를 DateTime으로 변환
      startDate: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class WorkerMedicationSummaryScreen extends StatefulWidget {
  final Elder? selectedElder;

  const WorkerMedicationSummaryScreen({Key? key, this.selectedElder}) : super(key: key);

  @override
  _WorkerMedicationSummaryScreenState createState() =>
      _WorkerMedicationSummaryScreenState();
}

class _WorkerMedicationSummaryScreenState
    extends State<WorkerMedicationSummaryScreen> {

  // 🔧 Firestore에서 약 목록을 불러오는 함수 수정
  Stream<List<Medication>> _getMedicationStream() {
    if (widget.selectedElder == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.selectedElder!.uid)
        .collection('medications')
        .snapshots()
        .map((snapshot) {
      // 🔧 시간을 제외한 오늘 날짜만 가져옵니다.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 🔧 데이터를 불러온 후, 앱에서 날짜를 비교하여 필터링
      return snapshot.docs
          .map((doc) => Medication.fromFirestore(doc.data()))
          .where((med) {
        // 🔧 시간을 제외한 시작일과 종료일을 가져옵니다.
        final startDate = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
        final endDate = DateTime(med.endDate.year, med.endDate.month, med.endDate.day);

        // 🔧 오늘 날짜가 시작일과 같거나 이후이고, 종료일과 같거나 이전인 약만 필터링
        return !today.isBefore(startDate) && !today.isAfter(endDate);
      })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedElder == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "대시보드에서 복약 상태를 확인할 어르신을 선택해주세요.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return StreamBuilder<List<Medication>>(
      stream: _getMedicationStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text("데이터를 불러오는 중 오류가 발생했습니다."));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("${widget.selectedElder!.name}님의 오늘 복용할 약이 없습니다."));
        }

        final medications = snapshot.data!;

        return ListView.builder(
          itemCount: medications.length,
          itemBuilder: (context, index) {
            final med = medications[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  med.taken ? Icons.check_circle : Icons.cancel,
                  color: med.taken ? Colors.green : Colors.red,
                  size: 40,
                ),
                title: Text(
                  med.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('복용 시간: ${med.time}'),
                trailing: Text(
                  med.taken ? '복용 완료' : '미복용',
                  style: TextStyle(
                    color: med.taken ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
