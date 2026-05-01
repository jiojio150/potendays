import 'package:flutter/material.dart';
import 'frontend/login.dart';
import 'frontend/home.dart';
import 'frontend/create_meeting.dart';
import 'frontend/schedule_input.dart';
import 'frontend/shared_calendar.dart';
import 'frontend/place_candidates.dart';
import 'frontend/settlement.dart';
import 'frontend/notifications.dart';
import 'frontend/confirmed_calendar.dart';

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
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/create-meeting': (context) => const CreateMeetingScreen(),
        '/schedule-input': (context) => const ScheduleInputScreen(),
        '/shared-calendar': (context) => const SharedCalendarScreen(),
        '/place-candidates': (context) => const PlaceCandidatesScreen(),
        '/settlement': (context) => const SettlementScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/confirmed-calendar': (context) => const ConfirmedCalendarScreen(),
      },
    );
  }
}
