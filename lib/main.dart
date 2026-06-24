import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

import 'app_navigator.dart';
import 'firebase_options.dart';
import 'frontend/confirmed_calendar.dart';
import 'frontend/home.dart';
import 'frontend/login.dart';
import 'frontend/notifications.dart';
import 'frontend/settings.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env의 카카오 앱 키를 사용한다.
  await dotenv.load(fileName: '.env');

  // Android, Web 등 현재 실행 플랫폼에 맞는 Firebase 설정을 자동 선택한다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // 카카오 SDK 초기화
  final String nativeAppKey =
      dotenv.env['KAKAO_NATIVE_APP_KEY']?.trim() ?? '';
  final String javaScriptAppKey =
      dotenv.env['KAKAO_JAVASCRIPT_APP_KEY']?.trim() ?? '';

  if (nativeAppKey.isNotEmpty || javaScriptAppKey.isNotEmpty) {
    KakaoSdk.init(
      nativeAppKey: nativeAppKey,
      javaScriptAppKey: javaScriptAppKey,
    );
  }


  // Blaze 없이 기기 자체에서 일정·정산 리마인드를 예약한다.
  await LocalNotificationService.instance.initialize();

  runApp(const PotenDaysApp());
}

class PotenDaysApp extends StatelessWidget {
  const PotenDaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poten Day',
      debugShowCheckedModeBanner: false,

      // 로컬 알림을 눌렀을 때 화면 밖에서도 Navigator를 사용하기 위한 키
      navigatorKey: appNavigatorKey,

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      initialRoute: '/',

      routes: {
        '/': (context) => const LoginScreen(),

        // 이전 코드에서 /login을 호출하더라도 같은 로그인 화면으로 이동
        '/login': (context) => const LoginScreen(),

        '/home': (context) => const HomeScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/confirmed-calendar': (context) =>
            const ConfirmedCalendarScreen(),
        '/settings': (context) => const SettingsScreen(),
      },

      // 등록되지 않은 경로가 호출돼 앱이 중단되는 것을 방지한다.
      onUnknownRoute: (settings) {
        final bool signedIn =
            FirebaseAuth.instance.currentUser != null;

        return MaterialPageRoute(
          builder: (_) =>
              signedIn ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
