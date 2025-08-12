import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String initialName;
  final String initialRole;   // '노인' | '보호자' | '복지사'
  final String initialPhone;
  final String initialAddress;
  final String photoUrl;

  const ProfileSetupScreen({
    super.key,
    required this.initialName,
    required this.initialRole,
    required this.initialPhone,
    required this.initialAddress,
    required this.photoUrl,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  late String _role;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _role = widget.initialRole;
    _phoneController = TextEditingController(text: widget.initialPhone);
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'userType': _role,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'onboarded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true); // 저장 완료 신호 (로그인 화면에서 처리)
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했습니다')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 뒤로가기(앱바/하드웨어) 눌렀을 때 로그인 화면으로 강제 이동
  void _goLogin() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.photoUrl.isNotEmpty
        ? CircleAvatar(radius: 36, backgroundImage: NetworkImage(widget.photoUrl))
        : const CircleAvatar(radius: 36, child: Icon(Icons.person));

    return WillPopScope(
      onWillPop: () async {
        // 프로필 편집 취소: 현재 라우트만 닫고 false 반환
        Navigator.pop(context, false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('프로필 설정'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: avatar),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: '노인', child: Text('노인')),
                  DropdownMenuItem(value: '보호자', child: Text('보호자')),
                  DropdownMenuItem(value: '복지사', child: Text('복지사')),
                ],
                onChanged: (v) => setState(() => _role = v ?? '노인'),
                decoration: const InputDecoration(
                  labelText: '회원 역할',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
