import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ddobaki_app/screens/worker/worker_dashboard_screen.dart'; // Elder 클래스를 위해 import

// 🔧 메모 데이터를 담을 모델 클래스
class WorkerNote {
  final String id;
  final String text;
  final DateTime createdAt;

  WorkerNote({required this.id, required this.text, required this.createdAt});

  factory WorkerNote.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return WorkerNote(
      id: doc.id,
      text: data['note_text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class WorkerNoteScreen extends StatefulWidget {
  final Elder? selectedElder;

  const WorkerNoteScreen({Key? key, this.selectedElder}) : super(key: key);

  @override
  _WorkerNoteScreenState createState() => _WorkerNoteScreenState();
}

class _WorkerNoteScreenState extends State<WorkerNoteScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  // 🔧 Firestore에 메모를 저장하는 함수
  Future<void> _saveNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty || widget.selectedElder == null) return;

    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(workerUid)
          .collection('notes_by_elder') // 어르신별 메모를 위한 새 컬렉션
          .doc(widget.selectedElder!.uid)
          .collection('notes')
          .add({
        'note_text': noteText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _noteController.clear();
      FocusScope.of(context).unfocus(); // 키보드 숨기기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("메모가 저장되었습니다.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("메모 저장 중 오류가 발생했습니다.")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🔧 Firestore에서 특정 어르신의 메모 목록을 불러오는 함수
  Stream<List<WorkerNote>> _getNotesStream() {
    if (widget.selectedElder == null) return Stream.value([]);

    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(workerUid)
        .collection('notes_by_elder')
        .doc(widget.selectedElder!.uid)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => WorkerNote.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedElder == null) {
      return Center(
        child: Text(
          "대시보드에서 메모를 확인할 어르신을 선택해주세요.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: [
        // 🔧 메모 목록을 보여주는 부분
        Expanded(
          child: StreamBuilder<List<WorkerNote>>(
            stream: _getNotesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text("${widget.selectedElder!.name}님에 대한 메모가 없습니다."));
              }
              final notes = snapshot.data!;
              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      title: Text(note.text),
                      subtitle: Text(DateFormat('yyyy년 M월 d일 HH:mm').format(note.createdAt)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // 🔧 메모 입력창 부분
        Divider(height: 1),
        Container(
          padding: EdgeInsets.all(12.0),
          color: Theme.of(context).cardColor,
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: "${widget.selectedElder!.name}님에 대한 메모 추가...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey.shade200,
                      filled: true,
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
                SizedBox(width: 8),
                _isSaving
                    ? CircularProgressIndicator()
                    : IconButton(
                  icon: Icon(Icons.send, color: Color(0xFF7B61FF)),
                  onPressed: _saveNote,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
