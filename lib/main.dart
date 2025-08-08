// main.dart
import 'package:ddobaki_app/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// 화면 import
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/elder/home_screen.dart';
import 'screens/elder/chat_screen.dart';
import 'screens/elder/diary_screen.dart';
import 'screens/elder/medication_screen.dart';
import 'screens/elder/report_screen.dart';
import 'screens/guardian/home_screen_guardian.dart';
import 'screens/worker/home_screen_worker.dart';
import 'screens/settings_screen.dart';
import 'screens/guardian/guardian_report_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TtbagiApp());
}

class TtbagiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또바기',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'NanumGothic',
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/forgot': (context) => ForgotPasswordScreen(),
        '/home_elder': (context) => HomeScreen(),
        '/chat': (context) => ChatScreen(),
        '/diary': (context) => DiaryScreen(),
        '/medication': (context) => MedicationScreen(),
        '/report': (context) => ReportScreen(),
        '/home_guardian': (context) => HomeScreenGuardian(),
        '/home_worker': (context) => HomeScreenWorker(),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}