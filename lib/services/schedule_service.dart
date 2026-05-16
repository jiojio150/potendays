import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';

// REQ-F-03, REQ-F-04, REQ-F-05
// 개인 일정 저장, 개인 일정 조회, 전체 참여자 일정 조회를 담당하는 서비스
class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // REQ-F-03 개인 일정 조회
  Future<ScheduleModel?> getUserSchedule(String docID, String uid) async {
    final doc = await _db
        .collection('meetings')
        .doc(docID)
        .collection('schedules')
        .doc(uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return ScheduleModel.fromMap(doc.data()!);
    }
    return null;
  }

  // REQ-F-03 개인 일정 저장
  Future<void> saveUserSchedule({
    required String docID,
    required ScheduleModel schedule,
  }) async {
    await _db
        .collection('meetings')
        .doc(docID)
        .collection('schedules')
        .doc(schedule.uid)
        .set(
          schedule.toMap(),
          SetOptions(merge: true),
        );
  }

  // REQ-F-04, REQ-F-05 전체 참여자 일정 조회
  Stream<List<ScheduleModel>> getGroupSchedulesStream(String docId) {
    return _db
        .collection('meetings')
        .doc(docId)
        .collection('schedules')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ScheduleModel.fromMap(doc.data());
      }).toList();
    });
  }
}
