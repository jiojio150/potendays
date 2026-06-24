import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'local_notification_service.dart';
import 'meeting_service.dart';

class ReminderSettingsData {
  final bool enabled;
  final int scheduleMinutesBefore;
  final int settlementDelayHours;
  final int inactiveDays;
  final DateTime? nextScheduleReminderAt;
  final DateTime? settlementReminderAt;
  final DateTime? nextInactiveReminderAt;

  const ReminderSettingsData({
    required this.enabled,
    required this.scheduleMinutesBefore,
    required this.settlementDelayHours,
    required this.inactiveDays,
    this.nextScheduleReminderAt,
    this.settlementReminderAt,
    this.nextInactiveReminderAt,
  });

  factory ReminderSettingsData.fromMap(Map<String, dynamic> map) {
    return ReminderSettingsData(
      enabled: map['reminderEnabled'] as bool? ?? true,
      scheduleMinutesBefore:
          (map['scheduleReminderMinutesBefore'] as num?)?.toInt() ??
              MeetingService.defaultScheduleReminderMinutesBefore,
      settlementDelayHours:
          (map['settlementReminderDelayHours'] as num?)?.toInt() ??
              MeetingService.defaultSettlementReminderDelayHours,
      inactiveDays:
          (map['inactiveReminderDays'] as num?)?.toInt() ??
              MeetingService.defaultInactiveReminderDays,
      nextScheduleReminderAt:
          (map['nextScheduleReminderAt'] as Timestamp?)?.toDate(),
      settlementReminderAt:
          (map['settlementReminderAt'] as Timestamp?)?.toDate(),
      nextInactiveReminderAt:
          (map['nextInactiveReminderAt'] as Timestamp?)?.toDate(),
    );
  }
}

// REQ-F-09 자동 리마인드가 사용할 설정과 실행 예정 상태를 관리한다.
class ReminderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<ReminderSettingsData> getSettings(String meetingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _db.collection('meetings').doc(meetingId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('모임 정보를 찾을 수 없습니다.');
    }

    return ReminderSettingsData.fromMap(data);
  }

  Future<void> saveSettings({
    required String meetingId,
    required bool enabled,
    required int scheduleMinutesBefore,
    required int settlementDelayHours,
    required int inactiveDays,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Google/Firebase 로그인이 필요합니다.');
    }

    final DocumentReference<Map<String, dynamic>> meetingRef =
        _db.collection('meetings').doc(meetingId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await meetingRef.get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('모임 정보를 찾을 수 없습니다.');
    }

    if ((data['creatorUid'] as String? ?? '') != user.uid) {
      throw StateError('모임장만 리마인드 설정을 변경할 수 있습니다.');
    }

    final Timestamp? confirmedTimestamp =
        data['confirmedDateTime'] as Timestamp?;
    final DateTime? confirmedDateTime =
        confirmedTimestamp?.toDate();

    final Map<String, dynamic> updates = {
      'reminderEnabled': enabled,
      'scheduleReminderMinutesBefore': scheduleMinutesBefore,
      'settlementReminderDelayHours': settlementDelayHours,
      'inactiveReminderDays': inactiveDays,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (confirmedDateTime != null) {
      updates.addAll({
        'nextScheduleReminderAt': Timestamp.fromDate(
          confirmedDateTime.subtract(
            Duration(minutes: scheduleMinutesBefore),
          ),
        ),
        'settlementReminderAt': Timestamp.fromDate(
          confirmedDateTime.add(
            Duration(hours: settlementDelayHours),
          ),
        ),
        'nextInactiveReminderAt': Timestamp.fromDate(
          confirmedDateTime.add(
            Duration(days: inactiveDays),
          ),
        ),
      });
    } else {
      updates.addAll({
        'nextScheduleReminderAt': FieldValue.delete(),
        'settlementReminderAt': FieldValue.delete(),
        'nextInactiveReminderAt': Timestamp.fromDate(
          DateTime.now().add(Duration(days: inactiveDays)),
        ),
      });
    }

    // 설정을 변경하면 새 조건으로 다시 판단할 수 있도록 미발송 상태로 초기화
    updates.addAll({
      'scheduleReminderSent': false,
      'scheduleReminderSentAt': FieldValue.delete(),
      'settlementReminderSent': false,
      'settlementReminderSentAt': FieldValue.delete(),
      'inactiveReminderSent': false,
      'inactiveReminderSentAt': FieldValue.delete(),
    });

    await meetingRef.update(updates);

    final String meetingTitle = data['title'] as String? ?? '모임';
    final bool settlementCompleted =
        data['settlementCompleted'] as bool? ?? false;

    if (!enabled) {
      await LocalNotificationService.instance.cancelMeetingReminders(
        meetingId,
      );
      return;
    }

    if (confirmedDateTime != null) {
      await LocalNotificationService.instance.scheduleMeetingReminders(
        meetingId: meetingId,
        meetingTitle: meetingTitle,
        confirmedDateTime: confirmedDateTime,
        enabled: true,
        scheduleMinutesBefore: scheduleMinutesBefore,
        settlementDelayHours: settlementDelayHours,
        inactiveDays: inactiveDays,
        settlementCompleted: settlementCompleted,
      );
      return;
    }

    await LocalNotificationService.instance.scheduleInactiveReminder(
      meetingId: meetingId,
      meetingTitle: meetingTitle,
      scheduledAt: DateTime.now().add(Duration(days: inactiveDays)),
      enabled: true,
    );
  }
}
