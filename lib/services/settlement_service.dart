import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/settlement_model.dart';

// REQ-F-08, REQ-F-09 정산 저장 및 자동 리마인드 상태 갱신
class SettlementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> getMeeting(
    String meetingId,
  ) {
    return _db.collection('meetings').doc(meetingId).get();
  }

  Future<SettlementModel?> getLatestSettlement(String meetingId) async {
    final snapshot = await _db
        .collection('meetings')
        .doc(meetingId)
        .collection('settlements')
        .doc('latest')
        .get();

    final Map<String, dynamic>? data = snapshot.data();
    return data == null ? null : SettlementModel.fromMap(data);
  }

  Map<String, int> calculateMemberAmounts({
    required int totalAmount,
    required List<String> participantUids,
  }) {
    if (participantUids.isEmpty || totalAmount <= 0) {
      return <String, int>{};
    }

    final int baseAmount = totalAmount ~/ participantUids.length;
    final int remainder = totalAmount % participantUids.length;
    final Map<String, int> result = <String, int>{};

    for (int index = 0; index < participantUids.length; index++) {
      result[participantUids[index]] =
          baseAmount + (index < remainder ? 1 : 0);
    }

    return result;
  }

  Future<void> saveSettlement({
    required String meetingId,
    required String meetingTitle,
    required int totalAmount,
    required List<String> participantUids,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Firebase 로그인이 필요합니다.');
    }
    if (participantUids.isEmpty) {
      throw StateError('정산할 참여자가 없습니다.');
    }
    if (totalAmount <= 0) {
      throw ArgumentError('총 지출 금액은 0원보다 커야 합니다.');
    }

    final DocumentReference<Map<String, dynamic>> meetingRef =
        _db.collection('meetings').doc(meetingId);

    final DocumentSnapshot<Map<String, dynamic>> meetingSnapshot =
        await meetingRef.get();

    final Map<String, dynamic>? meetingData = meetingSnapshot.data();

    if (!meetingSnapshot.exists || meetingData == null) {
      throw StateError('모임 정보를 찾을 수 없습니다.');
    }

    // 요구사항 정의에 따라 정산 입력은 모임장이 수행
    if ((meetingData['creatorUid'] as String? ?? '') != user.uid) {
      throw StateError('모임장만 정산 내역을 저장할 수 있습니다.');
    }

    final Map<String, int> memberAmounts = calculateMemberAmounts(
      totalAmount: totalAmount,
      participantUids: participantUids,
    );

    final SettlementModel settlement = SettlementModel(
      totalAmount: totalAmount,
      perPersonAmount: totalAmount ~/ participantUids.length,
      participantUids: participantUids,
      memberAmounts: memberAmounts,
      createdByUid: user.uid,
    );

    final DocumentReference<Map<String, dynamic>> settlementRef =
        meetingRef.collection('settlements').doc('latest');

    // 같은 정산을 수정할 때 알림이 계속 쌓이지 않도록 고정 ID 사용
    final DocumentReference<Map<String, dynamic>> notificationRef =
        meetingRef.collection('notifications').doc('settlement-latest');

    final WriteBatch batch = _db.batch();

    batch.set(
      settlementRef,
      settlement.toMap(),
      SetOptions(merge: true),
    );

    batch.update(meetingRef, {
      'settlementCompleted': true,
      'settledAt': FieldValue.serverTimestamp(),
      'settlementUpdatedByUid': user.uid,
      'settlementReminderAt': FieldValue.delete(),
      'settlementReminderSent': false,
      'settlementReminderSentAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      notificationRef,
      {
        'type': 'settlement',
        'title': '💸 정산 요청',
        'message':
            '$meetingTitle 정산이 등록되었습니다. 1인당 금액을 확인해 주세요.',
        'meetingId': meetingId,
        'meetingTitle': meetingTitle,
        'targetUids': participantUids,
        'readBy': <String>[],
        'createdByUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
