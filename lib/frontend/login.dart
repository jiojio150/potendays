import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static final AuthService _authService = AuthService();

  Future<void> _onGoogleLogin(BuildContext context) async {
    try {
      final user = await _authService.signInWithGoogle();

      if (user != null && context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (error, stackTrace) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        debugPrint('사용자가 Google 로그인 팝업을 닫았습니다.');
        return;
      }

      debugPrint('===== Google 로그인 실제 오류 =====');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 내용: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google 로그인 실패: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('===== Google 로그인 실제 오류 =====');
      debugPrint('오류 타입: ${error.runtimeType}');
      debugPrint('오류 내용: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google 로그인 중 오류가 발생했습니다.'),
        ),
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  카카오 로그인 함수
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _onKakaoLogin(BuildContext context) async {
    debugPrint('카카오 로그인 버튼이 눌렸습니다.');

    try {
      OAuthToken token;

      // Chrome/Web에서는 별도 백엔드 없이 카카오 로그인을 완료할 수 없으므로
      // 로그인 요청을 보내지 않고 모바일 앱 이용 안내만 표시한다.
      if (kIsWeb) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '카카오 로그인은 Android 또는 iOS 앱에서 이용해 주세요.',
            ),
          ),
        );
        return;
      } else if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          debugPrint('카카오톡 앱 로그인 성공');
        } on PlatformException catch (error, stackTrace) {
          if (error.code == 'CANCELED') {
            debugPrint('사용자가 카카오톡 로그인을 취소했습니다.');
            return;
          }

          debugPrint('카카오톡 앱 로그인 실패: ${error.code}');
          debugPrintStack(stackTrace: stackTrace);

          token = await UserApi.instance.loginWithKakaoAccount();
          debugPrint('카카오계정 로그인 성공');
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        debugPrint('카카오계정 로그인 성공');
      }

      debugPrint(
        '카카오 액세스 토큰 발급 완료: ${token.accessToken.isNotEmpty}',
      );

      final kakaoUser = await UserApi.instance.me();

      debugPrint('카카오 회원번호: ${kakaoUser.id}');
      debugPrint(
        '카카오 닉네임: ${kakaoUser.kakaoAccount?.profile?.nickname}',
      );

      if (!context.mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } on PlatformException catch (error, stackTrace) {
      if (error.code == 'CANCELED') {
        debugPrint('사용자가 카카오 로그인을 취소했습니다.');
        return;
      }

      debugPrint('===== 카카오 로그인 Platform 오류 =====');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 내용: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카카오 로그인 실패: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('===== 카카오 로그인 실제 오류 =====');
      debugPrint('오류 타입: ${error.runtimeType}');
      debugPrint('오류 내용: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카카오 로그인 중 오류가 발생했습니다.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              _AppLogo(),
              const SizedBox(height: 24),
              const Text('NTPC', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              
              const Spacer(flex: 1),

              _SocialLoginButton(
                onPressed: () => _onGoogleLogin(context),
                icon: _GoogleIcon(),
                label: 'Google로 시작하기',
                backgroundColor: Colors.white,
                textColor: Colors.black87,
              ),
              
              const SizedBox(height: 16),
              _SocialLoginButton(
                onPressed: () => _onKakaoLogin(context), 
                icon: _KakaoIcon(),
                label: '카카오톡으로 시작하기',
                backgroundColor: const Color(0xFFFEE500),
                textColor: Colors.black87,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 앱 로고 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A6CF7), Color(0xFF2E4BE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A6CF7).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.calendar_month_rounded,
        size: 50,
        color: Colors.white,
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 소셜 로그인 공통 버튼 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _SocialLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google 아이콘 (SVG 대신 텍스트 기반)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Kakao 아이콘
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _KakaoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'K',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF191919),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}