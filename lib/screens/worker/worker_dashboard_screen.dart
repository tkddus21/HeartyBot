import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 사용

class WorkerDashboardScreen extends StatefulWidget {
  @override
  _WorkerDashboardScreenState createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<Map<String, String>> elders = [
    {"name": "김철수", "status": "기쁨", "response": "O"},
    {"name": "이영희", "status": "불안", "response": "X"},
  ];

  void _showAddElderDialog() {
    TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("노인 추가하기"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("추가할 노인의 이메일을 입력하세요."),
            SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "example@email.com",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("추가"),
            onPressed: () async {
              String email = _emailController.text.trim();
              if (email.isEmpty) return;

              try {
                // Firestore에서 이메일 기준 사용자 조회
                QuerySnapshot snapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

                if (snapshot.docs.isNotEmpty) {
                  final data = snapshot.docs.first.data() as Map<String, dynamic>;
                  final String name = data['name'] ?? email.split('@')[0];

                  setState(() {
                    elders.add({
                      "name": name,
                      "status": "미확인",
                      "response": "O",
                    });
                  });

                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("해당 이메일로 등록된 노인을 찾을 수 없습니다.")),
                  );
                }
              } catch (e) {
                print("Firestore 오류: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("데이터를 불러오지 못했습니다.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteElder(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("삭제 확인"),
        content: Text("${elders[index]['name']} 어르신을 목록에서 삭제하시겠어요?"),
        actions: [
          TextButton(
            child: Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text("삭제"),
            onPressed: () {
              setState(() {
                elders.removeAt(index);
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: elders.length,
        itemBuilder: (context, index) {
          final elder = elders[index];
          return GestureDetector(
            onLongPress: () => _confirmDeleteElder(index),
            child: ListTile(
              title: Text("${elder['name']} 어르신", style: TextStyle(color: Color(0xFF333333))),
              subtitle: Text("기분: ${elder['status']} / 응답: ${elder['response']}", style: TextStyle(color: Color(0xFF333333))),
              leading: Icon(Icons.person),
              trailing: elder['response'] == 'O'
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : Icon(Icons.error, color: Colors.red),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF7B61FF),
        child: Icon(Icons.person_add),
        onPressed: _showAddElderDialog,
        tooltip: "노인 추가하기",
      ),
    );
  }
}
