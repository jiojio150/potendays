import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app_navigator.dart';
import '../frontend/notification_router.dart';
import '../models/app_notification_model.dart';

/// Blaze/Cloud Functions 없이 각 기기에서 모임 리마인드를 예약한다.
///
/// Android, iOS, macOS에서만 예약 알림을 사용한다.
/// 웹에서는 미래 시각 예약 알림을 지원하지 않으므로 아무 작업도 하지 않는다.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String channelId = 'potendays_reminders';
  static const String channelName = 'Poten Day 리마인드';
  static const String channelDescription = '모임 일정, 정산 및 장기간 미모임 리마인드';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;

  bool get isSupported {
    if (kIsWeb) return false;

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    tz.initializeTimeZones();

    try {
      final TimezoneInfo currentZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentZone.identifier));
    } catch (error) {
      // 한국에서 실행하는 프로젝트이므로 기기 시간대 조회 실패 시 서울로 대체한다.
      debugPrint('기기 시간대 확인 실패: $error');
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  /// 모임 일정이 확정되었을 때 일정, 정산, 장기 미모임 알림을 다시 예약한다.
  Future<void> scheduleMeetingReminders({
    required String meetingId,
    required String meetingTitle,
    required DateTime confirmedDateTime,
    required bool enabled,
    required int scheduleMinutesBefore,
    required int settlementDelayHours,
    required int inactiveDays,
    bool settlementCompleted = false,
    bool requestPermission = true,
  }) async {
    if (!isSupported) return;
    await initialize();

    if (requestPermission) {
      await requestPermissions();
    }

    await cancelMeetingReminders(meetingId);
    if (!enabled) return;

    final DateTime scheduleAt = confirmedDateTime.subtract(
      Duration(minutes: scheduleMinutesBefore),
    );
    final DateTime settlementAt = confirmedDateTime.add(
      Duration(hours: settlementDelayHours),
    );
    final DateTime inactiveAt = confirmedDateTime.add(
      Duration(days: inactiveDays),
    );

    await _scheduleIfFuture(
      id: _notificationId(meetingId, 'schedule'),
      title: '🗓 모임 일정이 다가오고 있어요',
      body: '$meetingTitle 일정이 곧 시작됩니다.',
      scheduledAt: scheduleAt,
      payload: NotificationRouter.payload(
        type: AppNotificationType.schedule,
        meetingId: meetingId,
      ),
    );

    if (!settlementCompleted) {
      await _scheduleIfFuture(
        id: _notificationId(meetingId, 'settlement'),
        title: '💳 정산 내역을 확인해 주세요',
        body: '$meetingTitle 모임의 정산이 필요한지 확인해 주세요.',
        scheduledAt: settlementAt,
        payload: NotificationRouter.payload(
          type: AppNotificationType.settlement,
          meetingId: meetingId,
        ),
      );
    }

    await _scheduleIfFuture(
      id: _notificationId(meetingId, 'inactive'),
      title: '👋 다음 모임을 만들어 볼까요?',
      body: '$meetingTitle 모임 이후 새로운 일정이 등록되지 않았어요.',
      scheduledAt: inactiveAt,
      payload: NotificationRouter.payload(
        type: AppNotificationType.reminder,
        meetingId: meetingId,
      ),
    );
  }

  /// 일정이 아직 확정되지 않은 새 모임의 장기 미모임 알림만 예약한다.
  Future<void> scheduleInactiveReminder({
    required String meetingId,
    required String meetingTitle,
    required DateTime scheduledAt,
    required bool enabled,
    bool requestPermission = true,
  }) async {
    if (!isSupported) return;
    await initialize();

    if (requestPermission) {
      await requestPermissions();
    }

    await _plugin.cancel(id: _notificationId(meetingId, 'inactive'));

    if (!enabled) return;

    await _scheduleIfFuture(
      id: _notificationId(meetingId, 'inactive'),
      title: '👋 모임 일정을 정해 볼까요?',
      body: '$meetingTitle 모임의 날짜와 장소를 정해 주세요.',
      scheduledAt: scheduledAt,
      payload: NotificationRouter.payload(
        type: AppNotificationType.reminder,
        meetingId: meetingId,
      ),
    );
  }

  Future<void> cancelMeetingReminders(String meetingId) async {
    if (!isSupported) return;
    await initialize();

    await Future.wait(<Future<void>>[
      _plugin.cancel(id: _notificationId(meetingId, 'schedule')),
      _plugin.cancel(id: _notificationId(meetingId, 'settlement')),
      _plugin.cancel(id: _notificationId(meetingId, 'inactive')),
    ]);
  }

  /// 로그인한 사용자가 참여한 모든 모임을 Firestore에서 다시 읽어
  /// 현재 기기의 예약 알림을 최신 상태로 맞춘다.
  Future<void> syncCurrentUserMeetings() async {
    if (!isSupported) return;

    final User? user = _auth.currentUser;
    if (user == null) return;

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('meetings')
        .where('participants', arrayContains: user.uid)
        .get();

    await syncMeetingDocuments(snapshot.docs);
  }

  /// 홈 화면의 최신 Firestore 문서 목록을 이용해 예약을 다시 만든다.
  Future<void> syncMeetingDocuments(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    if (!isSupported) return;
    await initialize();

    // 이 앱에서 사용하는 로컬 예약 알림을 모두 지운 뒤 최신 모임만 재등록한다.
    await _plugin.cancelAllPendingNotifications();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in documents) {
      await _scheduleFromMeetingDocument(document.id, document.data());
    }
  }

  Future<void> _scheduleFromMeetingDocument(
    String meetingId,
    Map<String, dynamic> data,
  ) async {
    final bool enabled = data['reminderEnabled'] as bool? ?? true;
    if (!enabled) return;

    final String meetingTitle = data['title'] as String? ?? '모임';
    final int scheduleMinutesBefore =
        (data['scheduleReminderMinutesBefore'] as num?)?.toInt() ?? 1440;
    final int settlementDelayHours =
        (data['settlementReminderDelayHours'] as num?)?.toInt() ?? 24;
    final int inactiveDays =
        (data['inactiveReminderDays'] as num?)?.toInt() ?? 30;
    final bool settlementCompleted =
        data['settlementCompleted'] as bool? ?? false;

    final DateTime? confirmedDateTime =
        (data['confirmedDateTime'] as Timestamp?)?.toDate();

    if (confirmedDateTime != null) {
      final DateTime scheduleAt =
          (data['nextScheduleReminderAt'] as Timestamp?)?.toDate() ??
          confirmedDateTime.subtract(Duration(minutes: scheduleMinutesBefore));
      final DateTime settlementAt =
          (data['settlementReminderAt'] as Timestamp?)?.toDate() ??
          confirmedDateTime.add(Duration(hours: settlementDelayHours));
      final DateTime inactiveAt =
          (data['nextInactiveReminderAt'] as Timestamp?)?.toDate() ??
          confirmedDateTime.add(Duration(days: inactiveDays));

      await _scheduleIfFuture(
        id: _notificationId(meetingId, 'schedule'),
        title: '🗓 모임 일정이 다가오고 있어요',
        body: '$meetingTitle 일정이 곧 시작됩니다.',
        scheduledAt: scheduleAt,
        payload: NotificationRouter.payload(
          type: AppNotificationType.schedule,
          meetingId: meetingId,
        ),
      );

      if (!settlementCompleted) {
        await _scheduleIfFuture(
          id: _notificationId(meetingId, 'settlement'),
          title: '💳 정산 내역을 확인해 주세요',
          body: '$meetingTitle 모임의 정산이 필요한지 확인해 주세요.',
          scheduledAt: settlementAt,
          payload: NotificationRouter.payload(
            type: AppNotificationType.settlement,
            meetingId: meetingId,
          ),
        );
      }

      await _scheduleIfFuture(
        id: _notificationId(meetingId, 'inactive'),
        title: '👋 다음 모임을 만들어 볼까요?',
        body: '$meetingTitle 모임 이후 새로운 일정이 등록되지 않았어요.',
        scheduledAt: inactiveAt,
        payload: NotificationRouter.payload(
          type: AppNotificationType.reminder,
          meetingId: meetingId,
        ),
      );

      return;
    }

    final DateTime? inactiveAt = (data['nextInactiveReminderAt'] as Timestamp?)
        ?.toDate();

    if (inactiveAt != null) {
      await _scheduleIfFuture(
        id: _notificationId(meetingId, 'inactive'),
        title: '👋 모임 일정을 정해 볼까요?',
        body: '$meetingTitle 모임의 날짜와 장소를 정해 주세요.',
        scheduledAt: inactiveAt,
        payload: NotificationRouter.payload(
          type: AppNotificationType.reminder,
          meetingId: meetingId,
        ),
      );
    }
  }

  Future<void> _scheduleIfFuture({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    final DateTime now = DateTime.now();
    if (!scheduledAt.isAfter(now.add(const Duration(seconds: 5)))) {
      return;
    }

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    final BuildContext? context = appNavigatorKey.currentContext;

    if (context == null || response.payload?.trim().isNotEmpty != true) {
      appNavigatorKey.currentState?.pushNamed('/notifications');
      return;
    }

    unawaited(NotificationRouter.openPayload(context, response.payload));
  }

  /// String.hashCode는 실행마다 달라질 수 있으므로 고정된 FNV-1a 해시를 사용한다.
  int _notificationId(String meetingId, String type) {
    final String value = '$type:$meetingId';
    int hash = 0x811C9DC5;

    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }

    return hash;
  }
}
