import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 기존 컨트롤러
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _extraInfoController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  DateTime? _birthDate;

  // 🔧 이메일 입력을 위한 새로운 컨트롤러 및 변수
  final _emailLocalPartController = TextEditingController();
  final _emailDomainController = TextEditingController();
  String _selectedDomain = 'naver.com';
  final List<String> _domains = ['naver.com', 'gmail.com', 'hanmail.net', '직접입력'];

  String _userType = '노인';
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _extraInfoController.dispose();
    _nameController.dispose();
    _birthController.dispose();
    _emailLocalPartController.dispose();
    _emailDomainController.dispose();
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
    // 🔧 이메일 주소 조합
    final String domain = _selectedDomain == '직접입력'
        ? _emailDomainController.text.trim()
        : _selectedDomain;
    final String email = '${_emailLocalPartController.text.trim()}@$domain';

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();

    // 유효성 검사
    if (_emailLocalPartController.text.trim().isEmpty || domain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 올바르게 입력해주세요.')),
      );
      return;
    }
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
      final bd = _birthDate!;
      final bdStr =
          '${bd.year.toString().padLeft(4, '0')}-'
          '${bd.month.toString().padLeft(2, '0')}-'
          '${bd.day.toString().padLeft(2, '0')}';

      final data = {
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'userType': _userType,
        'name': name,
        'birthDate': bd,
        'birthDateString': bdStr,
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
      final userDoc = fs.collection('users').doc(uid);
      batch.set(userDoc, data);

      if (_userType == '노인') {
        final emailKey = email.trim().toLowerCase();
        final idxDoc = fs.collection('email_index').doc(emailKey);
        batch.set(idxDoc, {'uid': uid});
      }

      await batch.commit();
      await FirebaseAuth.instance.signOut();

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
      if(mounted) setState(() => _isLoading = false);
    }
  }


  Widget _buildExtraField() {
    if (_userType == '보호자') {
      return TextField(
        controller: _extraInfoController,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.link),
          labelText: '연결할 노인 이메일',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (_userType == '복지사') {
      return TextField(
        controller: _extraInfoController,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.business),
          labelText: '소속 기관명',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔧 UI 개선 적용
            DropdownButtonFormField<String>(
              value: _userType,
              items: ['노인', '보호자', '복지사']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _userType = v!),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.people_outline),
                labelText: '회원 유형 선택',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            _buildExtraField(),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined),
                labelText: '이름',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _birthController,
              readOnly: true,
              onTap: _pickBirthDate,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.cake_outlined),
                labelText: '생년월일',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // 🔧 이메일 입력 UI
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailLocalPartController,
                    decoration: InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("@", style: TextStyle(fontSize: 16)),
                ),
                Expanded(
                  child: _selectedDomain == '직접입력'
                      ? TextField(
                    controller: _emailDomainController,
                    decoration: InputDecoration(
                      labelText: '도메인 입력',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                      ),
                    ),
                  )
                      : DropdownButtonFormField<String>(
                    value: _selectedDomain,
                    items: _domains
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDomain = v!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                labelText: '비밀번호',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_person_outlined),
                labelText: '비밀번호 확인',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                labelText: '전화번호',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.home_outlined),
                labelText: '집 주소',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('회원가입', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
