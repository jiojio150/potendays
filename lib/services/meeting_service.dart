import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// REQ-F-02, REQ-F-13, REQ-F-14
// 모임 생성, 모임 참여, 내가 참여한 모임 조회를 담당하는 서비스
class MeetingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REQ-F-02 모임 생성
  Future<void> createMeeting({
    required String title,
    required String emoji,
    required String creatorUid,
    required List<String> participants,
    required String description,
    required int participantCount,
  }) async {
    await _db.collection('meetings').add({
      'title': title,
      'emoji': emoji,
      'creatorUid': creatorUid,
      'participants': participants,
      'description': description,
      'participantLimit': participantCount,
      'participantCount': participants.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // REQ-F-14 모임 참여
  Future<String> joinMeeting(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return '로그인이 필요합니다.';

    final uid = user.uid;
    final docRef = _db.collection('meetings').doc(docId);

    try {
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) return 'not_found';

      final List<dynamic> participants =
          docSnapshot.data()?['participants'] ?? [];

      if (participants.contains(uid)) {
        return 'already_joined';
      }

      await docRef.update({
        'participants': FieldValue.arrayUnion([uid]),
        'participantCount': FieldValue.increment(1),
      });

      return 'success';
    } catch (e) {
      debugPrint('모임 참여 에러: $e');
      return 'error';
    }
  }

  // REQ-F-13 내가 참여 중인 모임 조회
  Stream<QuerySnapshot> getMyMeetings(String uid) {
    return _db
        .collection('meetings')
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
