import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

// REQ-F-01 로그인: FirebaseAuth와 GoogleSignIn을 이용한 인증 처리 서비스
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firestore 사용자 정보 저장을 위한 객체
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // .env에 저장된 Google Client ID를 사용해 구글 로그인 객체 생성
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  // REQ-F-01: 사용자가 구글 로그인을 선택했을 때 인증 절차를 진행
  Future<UserCredential?> signInWithGoogle() async {
    // 로그인 창에서 사용자가 취소한 경우 null 반환
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      return null;
    }

    // 구글 인증 토큰을 Firebase 인증 정보로 변환
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Firebase에 로그인 처리
    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );

    final User? user = userCredential.user;

    // 프로필 저장에 실패하더라도 로그인 자체는 유지
    if (user != null) {
      try {
        await _saveUserProfile(user);
      } catch (e) {
        debugPrint('사용자 프로필 저장 오류: $e');
      }
    }

    return userCredential;
  }

  // 로그인한 사용자 정보를 Firestore에 저장
  Future<void> _saveUserProfile(User user) async {
    final String displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? '사용자';

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': displayName,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 로그인 상태 해제
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
