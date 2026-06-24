import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 로그인 사용자의 공개 프로필 저장 및 참여자 이름 조회
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveFirebaseUserProfile(User user) async {
    final String displayName =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : '사용자';

    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'photoUrl': user.photoURL,
      'provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'firebase',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, String>> getDisplayNames(List<String> uids) async {
    if (uids.isEmpty) return <String, String>{};

    final List<DocumentSnapshot<Map<String, dynamic>>> documents =
        await Future.wait(
      uids.map((uid) => _db.collection('users').doc(uid).get()),
    );

    final Map<String, String> result = <String, String>{};

    for (int index = 0; index < uids.length; index++) {
      final String uid = uids[index];
      final Map<String, dynamic>? data = documents[index].data();
      final String? savedName = data?['displayName'] as String?;

      if (savedName != null && savedName.trim().isNotEmpty) {
        result[uid] = savedName.trim();
      } else {
        result[uid] = '참여자 ${index + 1}';
      }
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && uids.contains(currentUser.uid)) {
      final String? currentName = currentUser.displayName;
      if (currentName != null && currentName.trim().isNotEmpty) {
        result[currentUser.uid] = currentName.trim();
      }
    }

    return result;
  }
}
