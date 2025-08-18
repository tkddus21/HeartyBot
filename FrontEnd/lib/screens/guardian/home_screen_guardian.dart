import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guardian_report_screen.dart';
import 'guardian_emotion_diary_screen.dart';
import 'guardian_medication_screen.dart';
import '../settings_screen_second.dart';

class HomeScreenGuardian extends StatefulWidget {
  const HomeScreenGuardian({super.key});

  @override
  State<HomeScreenGuardian> createState() => _HomeScreenGuardianState();
}

class _HomeScreenGuardianState extends State<HomeScreenGuardian> {
  final _purple = const Color(0xFF7B61FF);
  final _bg = const Color(0xFFF6F5FC);
  int _idx = 0;

  final _pages = const [
    GuardianReportScreen(),
    GuardianEmotionDiaryScreen(),
    GuardianMedicationScreen(),
  ];

  /// 보호자 → elderUid → 어르신 이름을 스트림으로 가져와 AppBar 제목 구성
  Widget _buildDynamicTitle() {
    final guardianUid = FirebaseAuth.instance.currentUser!.uid;
    final guardianRef =
    FirebaseFirestore.instance.collection('users').doc(guardianUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: guardianRef.snapshots(),
      builder: (context, gSnap) {
        if (!gSnap.hasData) {
          return const Text('담당 어르신 요약');
        }
        final elderUid = gSnap.data!.data()?['elderUid'] as String?;
        if (elderUid == null || elderUid.isEmpty) {
          return const Text('담당 어르신 요약');
        }

        final elderRef =
        FirebaseFirestore.instance.collection('users').doc(elderUid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: elderRef.snapshots(),
          builder: (context, eSnap) {
            if (!eSnap.hasData || !eSnap.data!.exists) {
              return const Text('담당 어르신 요약');
            }
            final name = (eSnap.data!.data()?['name'] ?? '').toString().trim();
            final title =
            name.isEmpty ? '담당 어르신 요약' : '$name님 오늘의 케어 요약';
            return Text(title, overflow: TextOverflow.ellipsis);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreenSecond()),
            );
          },
        ),
        title: _buildDynamicTitle(),
      ),
      body: _pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        selectedItemColor: _purple,
        unselectedItemColor: const Color(0xFFBDBDBD),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions), label: '감정'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: '약'),
        ],
      ),
    );
  }
}
