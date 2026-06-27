import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';

// REQ-F-02, REQ-F-09, REQ-F-13, REQ-F-14
// 모임 생성·참여·확정 및 자동 리마인드에 필요한 상태 데이터를 관리한다.
class MeetingService {
  static const int defaultScheduleReminderMinutesBefore = 1440; // 1일 전
  static const int defaultSettlementReminderDelayHours = 24; // 모임 1일 후
  static const int defaultInactiveReminderDays = 30; // 30일간 모임 없음

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REQ-F-02 모임 생성
  Future<String> createMeeting({
    required String title,
    required String emoji,
    required String creatorUid,
    required List<String> participants,
    required String description,
    required String inviteMethod,
    int? participantLimit,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Firebase에 로그인된 사용자가 없습니다.');
    }

    if (creatorUid != user.uid) {
      throw StateError('로그인 사용자와 모임 생성자 정보가 일치하지 않습니다.');
    }

    final List<String> safeParticipants = <String>{
      ...participants,
      user.uid,
    }.toList();

    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> meetingRef = await _db
        .collection('meetings')
        .add({
          'title': title,
          'emoji': emoji,
          'creatorUid': user.uid,
          'participants': safeParticipants,
          'description': description,
          'inviteMethod': inviteMethod,
          if (participantLimit != null) 'participantLimit': participantLimit,
          'participantCount': safeParticipants.length,

          // 모임 확정 상태
          'isConfirmed': false,

          // 자동 리마인드 기본 설정
          'reminderEnabled': true,
          'scheduleReminderMinutesBefore': defaultScheduleReminderMinutesBefore,
          'settlementReminderDelayHours': defaultSettlementReminderDelayHours,
          'inactiveReminderDays': defaultInactiveReminderDays,

          // 리마인드 처리 상태
          'scheduleReminderSent': false,
          'settlementCompleted': false,
          'settlementReminderSent': false,
          'inactiveReminderSent': false,

          // 아직 확정 일정은 없지만, 장기간 모임 없음 리마인드 기준은 생성일부터 시작
          'nextInactiveReminderAt': Timestamp.fromDate(
            now.add(const Duration(days: defaultInactiveReminderDays)),
          ),

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await LocalNotificationService.instance.scheduleInactiveReminder(
      meetingId: meetingRef.id,
      meetingTitle: title,
      scheduledAt: now.add(const Duration(days: defaultInactiveReminderDays)),
      enabled: true,
    );

    return meetingRef.id;
  }

  // 앱 내부에서 공유하는 초대 링크
  static String createInviteLink(String meetingId) {
    return Uri(
      scheme: 'potendays',
      host: 'join',
      queryParameters: <String, String>{'meetingId': meetingId},
    ).toString();
  }

  // 초대 코드, potendays 링크, 일반 URL에서 meetingId 추출
  static String extractMeetingId(String rawInput) {
    final String input = rawInput.trim();

    if (input.isEmpty) return '';

    final Uri? uri = Uri.tryParse(input);

    if (uri != null && uri.hasScheme) {
      final String? queryMeetingId =
          uri.queryParameters['meetingId'] ??
          uri.queryParameters['meetingID'] ??
          uri.queryParameters['code'];

      if (queryMeetingId != null && queryMeetingId.trim().isNotEmpty) {
        return queryMeetingId.trim();
      }

      if (uri.pathSegments.isNotEmpty) {
        final int joinIndex = uri.pathSegments.indexOf('join');

        if (joinIndex >= 0 && joinIndex + 1 < uri.pathSegments.length) {
          return uri.pathSegments[joinIndex + 1].trim();
        }

        return uri.pathSegments.last.trim();
      }
    }

    return input;
  }

  // REQ-F-14 모임 참여
  Future<String> joinMeeting(String rawInput) async {
    final String docId = extractMeetingId(rawInput);
    final User? user = _auth.currentUser;

    if (user == null) {
      return 'login_required';
    }

    if (docId.isEmpty) {
      return 'not_found';
    }

    final String uid = user.uid;
    final DocumentReference<Map<String, dynamic>> docRef = _db
        .collection('meetings')
        .doc(docId);

    try {
      final String result = await _db.runTransaction<String>((
        transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(docRef);

        if (!snapshot.exists) {
          return 'not_found';
        }

        final Map<String, dynamic> data = snapshot.data()!;
        final List<String> participants = List<String>.from(
          data['participants'] ?? <String>[],
        );

        if (participants.contains(uid)) {
          return 'already_joined';
        }

        final List<String> updatedParticipants = <String>[...participants, uid];

        transaction.update(docRef, {
          'participants': updatedParticipants,
          'participantCount': updatedParticipants.length,
        });

        return 'success';
      });

      if (result == 'success') {
        await LocalNotificationService.instance.syncCurrentUserMeetings();
      }

      return result;
    } on FirebaseException catch (error) {
      debugPrint('모임 참여 Firebase 오류: ${error.code} / ${error.message}');
      return 'error';
    } catch (error) {
      debugPrint('모임 참여 오류: $error');
      return 'error';
    }
  }

  // REQ-F-13 내가 참여 중인 모임 조회
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyMeetings(String uid) {
    return _db
        .collection('meetings')
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMeeting(String meetingId) {
    return _db.collection('meetings').doc(meetingId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMeeting(
    String meetingId,
  ) {
    return _db.collection('meetings').doc(meetingId).snapshots();
  }

  // 모임장이 최종 날짜·시간·장소 확정
  // 확정 시 자동 리마인드 실행 예정 시각도 함께 계산한다.
  Future<void> confirmMeeting({
    required String meetingId,
    required DateTime confirmedDateTime,
    required String placeName,
    required String placeAddress,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Google/Firebase 로그인이 필요합니다.');
    }

    final DocumentReference<Map<String, dynamic>> meetingRef = _db
        .collection('meetings')
        .doc(meetingId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await meetingRef
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('모임 정보를 찾을 수 없습니다.');
    }

    final Map<String, dynamic> data = snapshot.data()!;
    final String creatorUid = data['creatorUid'] as String? ?? '';

    if (creatorUid != user.uid) {
      throw StateError('모임장만 날짜와 장소를 확정할 수 있습니다.');
    }

    final List<String> participants = List<String>.from(
      data['participants'] ?? <String>[],
    );
    final String meetingTitle = data['title'] as String? ?? '모임';
    final String meetingEmoji = data['emoji'] as String? ?? '📅';

    final bool reminderEnabled = data['reminderEnabled'] as bool? ?? true;
    final int scheduleReminderMinutesBefore =
        (data['scheduleReminderMinutesBefore'] as num?)?.toInt() ??
        defaultScheduleReminderMinutesBefore;
    final int settlementReminderDelayHours =
        (data['settlementReminderDelayHours'] as num?)?.toInt() ??
        defaultSettlementReminderDelayHours;
    final int inactiveReminderDays =
        (data['inactiveReminderDays'] as num?)?.toInt() ??
        defaultInactiveReminderDays;

    final DateTime nextScheduleReminderAt = confirmedDateTime.subtract(
      Duration(minutes: scheduleReminderMinutesBefore),
    );
    final DateTime settlementReminderAt = confirmedDateTime.add(
      Duration(hours: settlementReminderDelayHours),
    );
    final DateTime nextInactiveReminderAt = confirmedDateTime.add(
      Duration(days: inactiveReminderDays),
    );

    final DocumentReference<Map<String, dynamic>> notificationRef = meetingRef
        .collection('notifications')
        .doc('schedule-confirmed');

    final WriteBatch batch = _db.batch();

    batch.update(meetingRef, {
      'isConfirmed': true,
      'confirmedDateTime': Timestamp.fromDate(confirmedDateTime),
      'confirmedPlaceName': placeName.trim(),
      'confirmedPlaceAddress': placeAddress.trim(),
      'confirmedByUid': user.uid,
      'confirmedAt': FieldValue.serverTimestamp(),

      // 리마인드 설정 및 다음 실행 예정 시각
      'reminderEnabled': reminderEnabled,
      'scheduleReminderMinutesBefore': scheduleReminderMinutesBefore,
      'settlementReminderDelayHours': settlementReminderDelayHours,
      'inactiveReminderDays': inactiveReminderDays,
      'nextScheduleReminderAt': Timestamp.fromDate(nextScheduleReminderAt),
      'settlementReminderAt': Timestamp.fromDate(settlementReminderAt),
      'nextInactiveReminderAt': Timestamp.fromDate(nextInactiveReminderAt),

      // 일정을 다시 확정하면 발송·정산 상태 초기화
      'scheduleReminderSent': false,
      'scheduleReminderSentAt': FieldValue.delete(),
      'settlementCompleted': false,
      'settledAt': FieldValue.delete(),
      'settlementUpdatedByUid': FieldValue.delete(),
      'settlementReminderSent': false,
      'settlementReminderSentAt': FieldValue.delete(),
      'inactiveReminderSent': false,
      'inactiveReminderSentAt': FieldValue.delete(),

      // 최근 확정된 모임 시각
      'lastMeetingAt': Timestamp.fromDate(confirmedDateTime),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 동일 모임의 확정 일정 알림은 한 문서를 갱신하여 중복 방지
    batch.set(notificationRef, {
      'type': 'schedule',
      'title': '🗓 모임 일정이 확정되었습니다',
      'message':
          '$meetingTitle · ${_formatDateTime(confirmedDateTime)} · ${placeName.trim()}',
      'meetingId': meetingId,
      'meetingTitle': meetingTitle,
      'meetingEmoji': meetingEmoji,
      'targetUids': participants,
      'readBy': <String>[],
      'createdByUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    await LocalNotificationService.instance.scheduleMeetingReminders(
      meetingId: meetingId,
      meetingTitle: meetingTitle,
      confirmedDateTime: confirmedDateTime,
      enabled: reminderEnabled,
      scheduleMinutesBefore: scheduleReminderMinutesBefore,
      settlementDelayHours: settlementReminderDelayHours,
      inactiveDays: inactiveReminderDays,
      settlementCompleted: false,
    );
  }

  static String _formatDateTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}.$month.$day $hour:$minute';
  }
}
