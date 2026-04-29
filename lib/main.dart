// lib/main.dart

import 'package:flutter/material.dart';
import 'frontend/login.dart';
import 'frontend/home.dart';
import 'frontend/create_meeting.dart';

void main() {
  runApp(const NTPCApp());
}

class NTPCApp extends StatelessWidget {
  const NTPCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NTPC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard', // 원하는 폰트로 교체 가능
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/create-meeting': (context) => const CreateMeetingScreen(),
      },
    );
  }
}