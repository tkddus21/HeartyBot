// login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  bool _argsApplied = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['prefillEmail'] is String) {
      final email = (args['prefillEmail'] as String).trim();
      if (email.isNotEmpty) _emailController.text = email;
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
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _ensureUserDocIfMissing(cred);
      final proceed = await _maybeOnboard();
      if (!proceed) {
        // 온보딩 취소 시 로그아웃 처리
        await FirebaseAuth.instance.signOut();
        return;
      }
      await _routeByRole();
    } on FirebaseAuthException catch (e) {
      _showAuthError(e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) return;

      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
        accessToken: gAuth.accessToken,
      );
      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _ensureUserDocWithRole(userCred);
      final proceed = await _maybeOnboard();
      if (!proceed) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        return;
      }
      await _routeByRole();
    } on FirebaseAuthException catch (e) {
      _showAuthError(e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureUserDocIfMissing(UserCredential cred) async {
    final user = cred.user!;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'name': user.displayName ?? '',
        'photoUrl': user.photoURL,
        'provider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'password',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _ensureUserDocWithRole(UserCredential userCred) async {
    final user = userCred.user!;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    final profile = userCred.additionalUserInfo?.profile ?? {};
    final name = user.displayName ?? (profile['name'] ?? '');
    final photoUrl = user.photoURL ?? (profile['picture'] ?? '');
    final email = user.email;

    String? role = snap.data()?['userType'] as String?;

    if (!snap.exists) {
      role = await _pickRoleBottomSheet();
      if (role == null) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
            code: 'cancelled', message: 'role not selected');
      }
      await ref.set({
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
        'provider': 'google.com',
        'userType': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false,
      }, SetOptions(merge: true));
    } else if (role == null || role.isEmpty) {
      role = await _pickRoleBottomSheet();
      if (role == null) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
            code: 'cancelled', message: 'role not selected');
      }
      await ref.set({
        'userType': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String?> _pickRoleBottomSheet() async {
    if (!mounted) return null;
    return await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('회원 역할을 선택하세요',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.elderly),
                  title: const Text('노인'),
                  onTap: () => Navigator.pop(ctx, '노인'),
                ),
                ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: const Text('보호자'),
                  onTap: () => Navigator.pop(ctx, '보호자'),
                ),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism),
                  title: const Text('복지사'),
                  onTap: () => Navigator.pop(ctx, '복지사'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _maybeOnboard() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    if (data['onboarded'] == true) return true;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileSetupScreen(
              initialName: (data['name'] ?? '') as String,
              initialRole: (data['userType'] ?? '노인') as String,
              initialPhone: (data['phone'] ?? '') as String,
              initialAddress: (data['address'] ?? '') as String,
              photoUrl: (data['photoUrl'] ?? '') as String,
            ),
      ),
    );

    return result == true;
  }

  Future<void> _routeByRole() async {
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

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, nextRoute, (route) => false);
  }

  void _showAuthError(String code) {
    String msg;
    switch (code) {
      case 'invalid-email':
        msg = '이메일 형식이 올바르지 않아요.';
        break;
      case 'user-not-found':
        msg = '등록되지 않은 이메일이에요.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        msg = '이메일 또는 비밀번호가 올바르지 않아요.';
        break;
      case 'account-exists-with-different-credential':
        msg = '이미 다른 로그인 방법으로 가입된 이메일이에요.';
        break;
      case 'network-request-failed':
        msg = '네트워크 오류가 발생했어요. 인터넷 연결을 확인해주세요.';
        break;
      default:
        msg = '로그인 실패: $code';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goToSignup() => Navigator.pushNamed(context, '/signup');

  void _goToForgotPassword() => Navigator.pushNamed(context, '/forgot');

  @override
  Widget build(BuildContext context) {
    // 🔧 UI 개선 시작
    return Scaffold(
      // 🔧 AppBar 제거 또는 단순화 (여기서는 제거)
      // appBar: AppBar(title: const Text('로그인')),
      body: SafeArea( // 🔧 SafeArea로 감싸서 상단 노치 등을 피함
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // 🔧 기존 일러스트 이미지로 변경 (파일 경로를 확인해주세요)
              Center(
                child: Image.asset('assets/logo.jpg',
                  width: 400,
                  // height: 180, // 너비에 맞춰 높이는 자동 조절되도록 설정
                ),
              ),
              const SizedBox(height: 40),

              // 🔧 이메일 입력창
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: '이메일',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔧 비밀번호 입력창
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 🔧 로그인 버튼
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('로그인', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),

              // 🔧 Google 로그인 버튼
              OutlinedButton.icon(
                onPressed: _loading ? null : _googleLogin,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                icon: Image.asset('assets/google.logo.png', width: 22, height: 22),
                label: const Text(
                  'Google로 계속하기',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20),

              // 🔧 회원가입 / 비밀번호 찾기
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: _goToSignup, child: const Text('회원가입')),
                  Text("|", style: TextStyle(color: Colors.grey.shade400)),
                  TextButton(
                      onPressed: _goToForgotPassword,
                      child: const Text('비밀번호 찾기')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
