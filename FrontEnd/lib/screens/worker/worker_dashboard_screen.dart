import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔧 어르신 정보를 담을 데이터 모델 클래스
class Elder {
  final String uid;
  final String name;
  final String lastEmotion; // 최근 감정
  // TODO: 마지막 응답 시간 등 추가 정보 필드

  Elder({
    required this.uid,
    required this.name,
    this.lastEmotion = "미확인",
  });
}

class WorkerDashboardScreen extends StatefulWidget {
  // 🔧 부모로부터 전달받을 콜백 함수와 선택된 어르신 정보
  final Function(Elder) onElderSelected;
  final Elder? selectedElder;

  const WorkerDashboardScreen({
    Key? key,
    required this.onElderSelected,
    this.selectedElder,
  }) : super(key: key);

  @override
  _WorkerDashboardScreenState createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<Elder> _managedElders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchManagedElders();
  }

  // 🔧 복지사가 담당하는 어르신 목록과 '최근 감정'을 함께 불러오는 함수
  Future<void> _fetchManagedElders() async {
    setState(() => _isLoading = true);
    final workerUid = FirebaseAuth.instance.currentUser?.uid;
    if (workerUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final workerDoc = await FirebaseFirestore.instance.collection('users').doc(workerUid).get();
      if (!workerDoc.exists || workerDoc.data()?['managed_elder_uids'] == null) {
        setState(() { _managedElders = []; _isLoading = false; });
        return;
      }

      final List<dynamic> elderUids = workerDoc.data()!['managed_elder_uids'];
      if (elderUids.isEmpty) {
        setState(() { _managedElders = []; _isLoading = false; });
        return;
      }

      List<Elder> eldersList = [];
      for (String uid in elderUids) {
        final elderDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (elderDoc.exists) {
          final data = elderDoc.data()!;

          // 🔧 각 어르신의 가장 최근 일기를 조회하여 감정 상태를 가져옵니다.
          String lastEmotion = "미확인";
          final diaryQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('diaries')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (diaryQuery.docs.isNotEmpty) {
            lastEmotion = diaryQuery.docs.first.data()['emotion'] ?? '미확인';
          }

          eldersList.add(Elder(
            uid: uid,
            name: data['name'] ?? '이름 없음',
            lastEmotion: lastEmotion, // 🔧 DB에서 가져온 최근 감정으로 업데이트
          ));
        }
      }

      setState(() {
        _managedElders = eldersList;
        _isLoading = false;
      });

    } catch (e) {
      print("담당 어르신 정보 로딩 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("어르신 목록을 불러오는 중 오류가 발생했습니다.")),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // 🔧 노인 추가하기 기능 (오류 처리 강화)
  void _showAddElderDialog() {
    TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("어르신 추가하기"),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(hintText: "어르신의 이메일을 입력하세요"),
        ),
        actions: [
          TextButton(
            child: Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("추가"),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              final workerUid = FirebaseAuth.instance.currentUser?.uid;
              if (workerUid == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("로그인이 필요합니다.")));
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("어르신을 찾는 중...")));

              try {
                // 🔧 복합 색인이 필요 없도록 이메일로만 먼저 검색합니다.
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

                if (query.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("해당 이메일의 사용자를 찾을 수 없습니다.")),
                  );
                  return;
                }

                final userDoc = query.docs.first;
                final userData = userDoc.data();

                // 🔧 검색된 사용자가 '노인'이 맞는지 앱에서 확인합니다.
                if (userData['userType'] != '노인') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("해당 사용자는 어르신 계정이 아닙니다.")),
                  );
                  return;
                }

                final elderUid = userDoc.id;
                await FirebaseFirestore.instance.collection('users').doc(workerUid).update({
                  'managed_elder_uids': FieldValue.arrayUnion([elderUid])
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("어르신을 추가했습니다.")),
                );
                _fetchManagedElders(); // 목록 새로고침

              } catch (e) {
                print("어르신 추가 실패: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("어르신 추가 중 오류가 발생했습니다.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // 🔧 어르신 삭제 기능
  void _confirmDeleteElder(Elder elder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("삭제 확인"),
        content: Text("${elder.name} 어르신을 목록에서 삭제하시겠습니까?"),
        actions: [
          TextButton(
            child: Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("삭제"),
            onPressed: () async {
              final workerUid = FirebaseAuth.instance.currentUser?.uid;
              if (workerUid == null) return;

              await FirebaseFirestore.instance.collection('users').doc(workerUid).update({
                'managed_elder_uids': FieldValue.arrayRemove([elder.uid])
              });

              Navigator.pop(context);
              _fetchManagedElders(); // 목록 새로고침
            },
          ),
        ],
      ),
    );
  }


  // 🔧 감정 상태에 따라 색상을 반환하는 헬퍼 함수
  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case '긍정':
        return Colors.green;
      case '부정':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _managedElders.isEmpty
          ? Center(child: Text("담당하고 있는 어르신이 없습니다.\n하단의 + 버튼으로 추가해주세요."))
          : RefreshIndicator(
        onRefresh: _fetchManagedElders,
        child: ListView.builder(
          itemCount: _managedElders.length,
          itemBuilder: (context, index) {
            final elder = _managedElders[index];
            final isSelected = widget.selectedElder?.uid == elder.uid;
            return ListTile(
              leading: CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text("${elder.name} 어르신"),
              subtitle: Row(
                children: [
                  Text("최근 감정: "),
                  Text(
                    elder.lastEmotion,
                    style: TextStyle(
                      color: _getEmotionColor(elder.lastEmotion),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              tileColor: isSelected ? Colors.deepPurple.withOpacity(0.1) : null,
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => widget.onElderSelected(elder),
              onLongPress: () => _confirmDeleteElder(elder),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF7B61FF),
        child: Icon(Icons.add),
        onPressed: _showAddElderDialog,
        tooltip: "어르신 추가하기",
      ),
    );
  }
}
