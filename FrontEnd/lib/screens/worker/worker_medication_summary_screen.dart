import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 상세 복용 기록을 담을 모델 클래스
class DoseRecord {
  final String medName;
  final String scheduledTime;
  final String status; // 'pending', 'taken', 'skipped' 등

  DoseRecord({
    required this.medName,
    required this.scheduledTime,
    required this.status,
  });
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

  // 🔧 선택된 날짜의 복용 기록을 불러오는 함수
  Future<List<DoseRecord>> _getDoseRecords() async {
    if (widget.selectedElder == null) return [];

    // 🔧 홈 화면에서 날짜를 선택하는 기능이 아직 없으므로, 일단 오늘 날짜를 기준으로 합니다.
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final dosesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.selectedElder!.uid)
        .collection('days')
        .doc(todayStr)
        .collection('doses')
        .get();

    if (dosesSnapshot.docs.isEmpty) return [];

    List<DoseRecord> records = [];
    for (var doc in dosesSnapshot.docs) {
      final data = doc.data();
      records.add(DoseRecord(
        medName: data['medName'] ?? '알 수 없는 약',
        scheduledTime: DateFormat('HH:mm').format((data['scheduledAt'] as Timestamp).toDate()),
        status: data['status'] ?? '미확인',
      ));
    }
    // 시간순으로 정렬
    records.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return records;
  }

  // 🔧 복용 상태에 따라 아이콘과 색상을 반환하는 헬퍼 함수
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty_rounded;
      default: // 'skipped', 'missed' 등
        return Icons.cancel;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'taken':
      case 'completed':
        return '복용 완료';
      case 'pending':
        return '복용 예정';
      default:
        return '미복용';
    }
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

    return FutureBuilder<List<DoseRecord>>(
      future: _getDoseRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text("데이터를 불러오는 중 오류가 발생했습니다."));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("${widget.selectedElder!.name}님의 오늘 복용 기록이 없습니다."));
        }

        final records = snapshot.data!;

        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  _getStatusIcon(record.status),
                  color: _getStatusColor(record.status),
                  size: 40,
                ),
                title: Text(
                  record.medName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('예정 시간: ${record.scheduledTime}'),
                trailing: Text(
                  _getStatusText(record.status),
                  style: TextStyle(
                    color: _getStatusColor(record.status),
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
