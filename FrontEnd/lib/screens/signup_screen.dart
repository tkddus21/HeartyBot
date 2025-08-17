import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _extraInfoController = TextEditingController();

  // 추가: 이름 / 생년월일
  final _nameController = TextEditingController();
  final _birthController = TextEditingController(); // 표시용
  DateTime? _birthDate;

  String _userType = '노인';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _extraInfoController.dispose();
    _nameController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 70, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthController.text =
        '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

void _signup() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();
  final name = _nameController.text.trim();

  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이름을 입력해주세요.')),
    );
    return;
  }
  if (_birthDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('생년월일을 선택해주세요.')),
    );
    return;
  }
  if (password != confirmPassword) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    final uid = cred.user!.uid;

    // 생년월일 문자열(표시용)
    final bd = _birthDate!;
    final bdStr =
        '${bd.year.toString().padLeft(4, '0')}-'
        '${bd.month.toString().padLeft(2, '0')}-'
        '${bd.day.toString().padLeft(2, '0')}';

    // Firestore에 저장할 기본 데이터
    final data = {
      'uid': uid,
      'email': email.trim().toLowerCase(), // 이메일은 소문자로 정규화 권장
      'userType': _userType,
      'name': name,
      'birthDate': bd,          // Timestamp로 저장됨
      'birthDateString': bdStr, // 표시용
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (_userType == '보호자') {
      data['elderEmail'] = _extraInfoController.text.trim().toLowerCase();
    } else if (_userType == '복지사') {
      data['orgName'] = _extraInfoController.text.trim();
    }

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    // users/{uid}
    final userDoc = fs.collection('users').doc(uid);
    batch.set(userDoc, data);

    // ✅ 노인 가입 시: email_index/{email} → { uid } 추가
    if (_userType == '노인') {
      final emailKey = email.trim().toLowerCase();
      final idxDoc = fs.collection('email_index').doc(emailKey);
      batch.set(idxDoc, {'uid': uid});
    }

    await batch.commit();

    // (선택) 보호자일 때, 가입 시점에 elderEmail을 입력했다면
    // 여기서 email_index를 조회해 elderUid를 바로 연결하는 로직을 추가할 수도 있음.
    // 하지만 보통은 "연결" 화면에서 별도로 처리.

    //  가입 직후 자동 로그아웃
    await FirebaseAuth.instance.signOut();

    //  로그인 화면으로 이동 (이메일 프리필)
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
      arguments: {'prefillEmail': email},
    );
    
  } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? '회원가입 실패')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}


  Widget _buildExtraField() {
    if (_userType == '보호자') {
      return TextField(
        controller: _extraInfoController,
        decoration: const InputDecoration(
          labelText: '연결할 노인 이메일',
          border: OutlineInputBorder(),
        ),
      );
    } else if (_userType == '복지사') {
      return TextField(
        controller: _extraInfoController,
        decoration: const InputDecoration(
          labelText: '소속 기관명',
          border: OutlineInputBorder(),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _userType,
              items: ['노인', '보호자', '복지사']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _userType = v!),
              decoration: const InputDecoration(
                labelText: '회원 유형 선택',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _buildExtraField(),
            const SizedBox(height: 12),

            // 이름
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 생년월일
            TextField(
              controller: _birthController,
              readOnly: true,
              onTap: _pickBirthDate,
              decoration: const InputDecoration(
                labelText: '생년월일 (YYYY-MM-DD)',
                hintText: '생년월일을 선택해주세요',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 확인',
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
                labelText: '집 주소',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}
