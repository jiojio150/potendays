import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import 'confirm_meeting.dart';
import 'meeting_detail.dart';
import 'reminder_settings.dart';
import 'settlement_history.dart';

class NotificationRouter {
  const NotificationRouter._();

  static Future<void> open(
    BuildContext context, {
    required AppNotificationType type,
    required String meetingId,
    String meetingTitle = '',
    String meetingEmoji = '',
    String settlementId = '',
  }) async {
    final String safeMeetingId = meetingId.trim();

    if (safeMeetingId.isEmpty) {
      _showMessage(context, '연결할 모임 정보가 없습니다.');
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('meetings')
            .doc(safeMeetingId)
            .get();

    if (!context.mounted) return;

    if (!snapshot.exists || snapshot.data() == null) {
      _showMessage(context, '모임 정보를 찾을 수 없습니다.');
      return;
    }

    final Map<String, dynamic> data = snapshot.data()!;
    final String title = meetingTitle.trim().isNotEmpty
        ? meetingTitle.trim()
        : (data['title'] as String? ?? '모임');
    final String emoji = meetingEmoji.trim().isNotEmpty
        ? meetingEmoji.trim()
        : (data['emoji'] as String? ?? '📅');
    final String creatorUid = data['creatorUid'] as String? ?? '';

    Widget screen;

    switch (type) {
      case AppNotificationType.schedule:
        screen = ConfirmMeetingScreen(
          meetingId: safeMeetingId,
          meetingTitle: title,
          meetingEmoji: emoji,
        );
        break;
      case AppNotificationType.settlement:
        screen = SettlementHistoryScreen(
          meetingId: safeMeetingId,
          meetingTitle: title,
          meetingEmoji: emoji,
          initialSettlementId: settlementId.trim(),
        );
        break;
      case AppNotificationType.reminder:
        screen = ReminderSettingsScreen(
          meetingId: safeMeetingId,
          meetingTitle: title,
          creatorUid: creatorUid,
        );
        break;
      case AppNotificationType.general:
        screen = _buildMeetingDetailScreen(safeMeetingId, data, title, emoji);
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> openPayload(BuildContext context, String? payload) async {
    final _NotificationPayload parsed = _NotificationPayload.parse(payload);

    await open(
      context,
      type: parsed.type,
      meetingId: parsed.meetingId,
      settlementId: parsed.settlementId,
    );
  }

  static String payload({
    required AppNotificationType type,
    required String meetingId,
    String settlementId = '',
  }) {
    return jsonEncode(<String, String>{
      'type': type.name,
      'meetingId': meetingId,
      if (settlementId.trim().isNotEmpty) 'settlementId': settlementId.trim(),
    });
  }

  static MeetingDetailScreen _buildMeetingDetailScreen(
    String meetingId,
    Map<String, dynamic> data,
    String title,
    String emoji,
  ) {
    final List<dynamic> participants =
        data['participants'] as List<dynamic>? ?? <dynamic>[];
    final DateTime? confirmedDateTime =
        (data['confirmedDateTime'] as Timestamp?)?.toDate();
    final bool isConfirmed = data['isConfirmed'] as bool? ?? false;

    return MeetingDetailScreen(
      docID: meetingId,
      emoji: emoji,
      title: title,
      participantCount: participants.length,
      date: confirmedDateTime == null
          ? '미정'
          : _formatDateTime(confirmedDateTime),
      statusText: isConfirmed ? '일정 확정' : '일정 조율 중',
      hasWarning: false,
    );
  }

  static String _formatDateTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}.$month.$day $hour:$minute';
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationPayload {
  final AppNotificationType type;
  final String meetingId;
  final String settlementId;

  const _NotificationPayload({
    required this.type,
    required this.meetingId,
    this.settlementId = '',
  });

  factory _NotificationPayload.parse(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const _NotificationPayload(
        type: AppNotificationType.general,
        meetingId: '',
      );
    }

    final String raw = payload.trim();

    try {
      final Object? decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return _NotificationPayload(
          type: _parseType(decoded['type'] as String?),
          meetingId: decoded['meetingId'] as String? ?? '',
          settlementId: decoded['settlementId'] as String? ?? '',
        );
      }
    } catch (_) {
      // Older payloads stored only the meeting id. Keep supporting them.
    }

    return _NotificationPayload(
      type: AppNotificationType.general,
      meetingId: raw,
    );
  }

  static AppNotificationType _parseType(String? rawType) {
    return AppNotificationType.values.firstWhere(
      (type) => type.name == rawType,
      orElse: () => AppNotificationType.general,
    );
  }
}
