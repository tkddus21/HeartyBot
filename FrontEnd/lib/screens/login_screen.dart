// login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  bool _argsApplied = false; // arguments(프리필 이메일) 한 번만 적용

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 회원가입 화면에서 넘겨준 arguments의 prefillEmail을 읽어 세팅
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['prefillEmail'] is String) {
      final email = (args['prefillEmail'] as String).trim();
      if (email.isNotEmpty) {
        _emailController.text = email;
      }
    }
    _argsApplied = true;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) 실제 Firebase 이메일/비번 로그인
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2) Firestore에서 userType 읽어 역할별 홈으로 분기
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final role = (snap.data()?['userType'] ?? '노인') as String;

      String nextRoute;
      switch (role) {
        case '보호자':
          nextRoute = '/home_guardian';
          break;
        case '복지사':
          nextRoute = '/home_worker';
          break;
        case '노인':
        default:
          nextRoute = '/home_elder';
      }

      // 3) 백스택 제거 후 진입
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, nextRoute, (route) => false);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '로그인 실패')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알 수 없는 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToSignup() {
    Navigator.pushNamed(context, '/signup');
  }

  void _goToForgotPassword() {
    Navigator.pushNamed(context, '/forgot');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // 로고
            Center(
              child: Image.asset(
                'assets/logo.jpg',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // 이메일
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 비밀번호
            TextField(
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _login(),
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 로그인 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('로그인'),
              ),
            ),
            const SizedBox(height: 12),

            // 하단 링크들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _goToSignup,
                  child: const Text('회원가입'),
                ),
                TextButton(
                  onPressed: _goToForgotPassword,
                  child: const Text('아이디 / 비밀번호 찾기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
