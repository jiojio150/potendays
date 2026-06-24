import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();

  Future<UserCredential?> signInWithGoogle() async {
    late final UserCredential result;

    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      // Android 로그인
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential =
          GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      result = await _auth.signInWithCredential(credential);
    }

    final User? user = result.user;

    if (user != null) {
      await _userService.saveFirebaseUserProfile(user);
    }

    return result;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }

    await _auth.signOut();
  }
}