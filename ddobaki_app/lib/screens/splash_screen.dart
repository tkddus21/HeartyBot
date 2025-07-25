// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      body: Center(
        child: Image.asset(
          'assets/logo.jpg',
          height: screenHeight * 2 / 3,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
