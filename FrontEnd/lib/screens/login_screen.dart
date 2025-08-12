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

  bool _argsApplied = false; // arguments(프리필 이메일) 한 번만 적용

  // 필요한 스코프만 사용(추가 정보 필요하면 확장 가능)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 회원가입 화면에서 넘겨준 prefillEmail 적용
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;

    final args = ModalRoute
        .of(context)
        ?.settings
        .arguments;
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

      // 이메일/비번 로그인도 최초 로그인일 수 있으니 문서/온보딩 보장
      await _ensureUserDocIfMissing(cred);

      // ⬇️ 온보딩(프로필 설정) 필요 시 이동, 취소하면 더 이상 진행 X
      final proceed = await _maybeOnboard();
      if (!proceed) return;

      // ⬇️ 온보딩 완료 시에만 역할별 홈으로
      await _routeByRole();
    } on FirebaseAuthException catch (e) {
      _showAuthError(e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google 로그인
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      // 1) 구글 계정 선택
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) return; // 사용자가 취소

      // 2) 토큰
      final gAuth = await gUser.authentication;

      // 3) Firebase Auth 교환
      final credential = GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
        accessToken: gAuth.accessToken,
      );
      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 4) Firestore 사용자 문서/역할 보장(역할은 BottomSheet에서 선택)
      await _ensureUserDocWithRole(userCred);

      // 5) 온보딩(프로필) 필요하면 이동, 취소하면 중단
      final proceed = await _maybeOnboard();
      if (!proceed) return;

      // 6) 역할별 홈 라우팅
      await _routeByRole();
    } on FirebaseAuthException catch (e) {
      _showAuthError(e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Firestore 사용자 문서가 없으면 만들어 줌(이메일 로그인 대비)
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

  /// Firestore 문서/역할 보장 (구글 최초 로그인 시 BottomSheet로 역할 선택)
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
      // 문서가 없으면 기본 데이터 생성 + 역할 즉시 선택
      role = await _pickRoleBottomSheet();
      if (role == null) {
        await FirebaseAuth.instance.signOut(); // 취소 시 안전하게 로그아웃
        throw FirebaseAuthException(
            code: 'cancelled', message: 'role not selected');
      }
      await ref.set({
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
        'provider': 'google',
        'userType': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false, // 아직 프로필 미완료
      }, SetOptions(merge: true));
    } else if (role == null || role.isEmpty) {
      // 문서는 있으나 역할이 비어있으면 선택 받기
      role = await _pickRoleBottomSheet();
      if (role == null) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
            code: 'cancelled', message: 'role not selected');
      }
      await ref.set({
        'userType': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// 역할 선택 BottomSheet
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

  /// 온보딩 필요 시 프로필 설정 화면으로 이동하고, 저장 완료(True)일 때만 계속 진행
  Future<bool> _maybeOnboard() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    // 이미 온보딩 완료면 true
    if (data['onboarded'] == true) return true;

    // 아직이면 프로필 화면으로 진입 (뒤로가기=취소 시 false 반환)
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

  /// Firestore의 userType에 따라 라우팅
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
        leading: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Image.asset('assets/logo.jpg',
                  width: 220, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),

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

            // ✅ B안: 구글 로고 + 텍스트 버튼
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _loading ? null : _googleLogin,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                        'assets/google.logo.png', width: 22, height: 22),
                    const SizedBox(width: 10),
                    const Text('Google로 계속하기'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: _goToSignup, child: const Text('회원가입')),
                TextButton(
                    onPressed: _goToForgotPassword,
                    child: const Text('아이디 / 비밀번호 찾기')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}