import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createMeeting({
    required String title,
    required String emoji,
    required String creatorUid,
    required List<String> participants,
    String? description,
    int? participantCount,
  }) async {
    await _firestore.collection('meetings').add({
      'title': title,
      'emoji': emoji,
      'creatorUid': creatorUid,
      'participants': participants,
      'description': description,
      'participantCount': participantCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

Future<String> joinMeeting(String docId, String uid) async {
  final docRef = _firestore.collection('meetings').doc(docId);
  final docSnapshot = await docRef.get();
  
  if (!docSnapshot.exists) return "존재하지 않는 모임입니다.";

  List<dynamic> participants = docSnapshot.data()?['participants'] ?? [];

  if (participants.contains(uid)) {
    return "already_joined";
  }

  await docRef.update({
    'participants': FieldValue.arrayUnion([uid]),
    'participantCount': FieldValue.increment(1),
  });
  
  return "success";
}

  Stream<QuerySnapshot> getMyMeetings(String uid) {
    return _firestore
        .collection('meetings')
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  Stream<QuerySnapshot> getGroupAvailability(String docId) {
    return _firestore
        .collection('meetings')
        .doc(docId)
        .collection('availability')
        .snapshots();
  }
}