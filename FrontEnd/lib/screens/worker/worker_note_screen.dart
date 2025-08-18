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

  // 🔧 Firestore 경로를 쉽게 참조하기 위한 헬퍼 함수
  CollectionReference? _getNotesCollectionRef() {
    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null || widget.selectedElder == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(workerUid)
        .collection('notes_by_elder')
        .doc(widget.selectedElder!.uid)
        .collection('notes');
  }

  // 🔧 Firestore에 메모를 저장하는 함수
  Future<void> _saveNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) return;

    final notesRef = _getNotesCollectionRef();
    if (notesRef == null) return;

    setState(() => _isSaving = true);
    try {
      await notesRef.add({
        'note_text': noteText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _noteController.clear();
      FocusScope.of(context).unfocus();
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

  // 🔧 Firestore에서 메모를 삭제하는 함수
  Future<void> _deleteNote(String noteId) async {
    final notesRef = _getNotesCollectionRef();
    if (notesRef == null) return;

    try {
      await notesRef.doc(noteId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("메모가 삭제되었습니다.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("메모 삭제 중 오류가 발생했습니다.")),
      );
    }
  }

  // 🔧 메모 수정 팝업을 띄우는 함수
  void _showEditNoteDialog(WorkerNote note) {
    final editController = TextEditingController(text: note.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("메모 수정"),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            child: Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("저장"),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;

              final notesRef = _getNotesCollectionRef();
              if (notesRef == null) return;

              await notesRef.doc(note.id).update({
                'note_text': newText,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // 🔧 메모를 꾹 눌렀을 때 옵션(수정/삭제)을 보여주는 함수
  void _showNoteOptions(WorkerNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("메모 관리"),
        content: Text("이 메모를 수정하거나 삭제하시겠습니까?"),
        actions: [
          TextButton(
            child: Text("수정"),
            onPressed: () {
              Navigator.pop(context);
              _showEditNoteDialog(note);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("삭제"),
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
          ),
        ],
      ),
    );
  }

  // Firestore에서 특정 어르신의 메모 목록을 불러오는 함수
  Stream<List<WorkerNote>> _getNotesStream() {
    final notesRef = _getNotesCollectionRef();
    if (notesRef == null) return Stream.value([]);

    return notesRef
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
                      // 🔧 꾹 눌렀을 때 옵션 메뉴가 나타나도록 onLongPress 추가
                      onLongPress: () => _showNoteOptions(note),
                    ),
                  );
                },
              );
            },
          ),
        ),
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
