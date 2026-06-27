import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../services/notification_service.dart';
import 'notification_router.dart';

// 알림 센터 — REQ-F-09
// Firestore에 저장된 앱 내부 알림을 현재 Firebase 사용자 기준으로 조회
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: uid == null
                  ? const Center(
                      child: Text(
                        'Google/Firebase 로그인이 필요합니다.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder<List<AppNotificationModel>>(
                      stream: _notificationService.watchMyNotifications(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '알림을 불러오지 못했습니다.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          );
                        }

                        final List<AppNotificationModel> notifications =
                            snapshot.data ?? <AppNotificationModel>[];

                        if (notifications.isEmpty) {
                          return const Center(
                            child: Text(
                              '새로운 알림이 없습니다.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }

                        return _buildNotificationList(
                          context,
                          uid,
                          notifications,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    String uid,
    List<AppNotificationModel> notifications,
  ) {
    final Map<String, List<AppNotificationModel>> grouped =
        <String, List<AppNotificationModel>>{};

    for (final notification in notifications) {
      final String section = _sectionFor(notification.createdAt);
      grouped.putIfAbsent(section, () => <AppNotificationModel>[]);
      grouped[section]!.add(notification);
    }

    const List<String> sectionOrder = <String>['오늘', '어제', '이전'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        for (final section in sectionOrder)
          if (grouped[section]?.isNotEmpty == true) ...[
            _SectionLabel(label: section),
            const SizedBox(height: 12),
            ...grouped[section]!.map(
              (notification) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _NotificationCard(
                  color: _colorFor(notification.type),
                  title: notification.title,
                  message: notification.message,
                  time: _formatTime(notification.createdAt),
                  isRead: notification.isReadBy(uid),
                  onTap: () => _openNotification(context, notification),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    AppNotificationModel notification,
  ) async {
    await _notificationService.markAsRead(notification);

    if (!context.mounted) return;

    await NotificationRouter.open(
      context,
      type: notification.type,
      meetingId: notification.meetingId,
      meetingTitle: notification.meetingTitle,
      meetingEmoji: notification.meetingEmoji,
      settlementId: notification.settlementId,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: const Text(
        '알림',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _sectionFor(DateTime? createdAt) {
    if (createdAt == null) return '이전';

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime date = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final int difference = today.difference(date).inDays;
    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    return '이전';
  }

  static String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return '방금 전';

    final DateTime now = DateTime.now();
    final Duration difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inHours < 1) return '${difference.inMinutes}분 전';
    if (difference.inDays < 1) return '${difference.inHours}시간 전';
    if (difference.inDays == 1) return '어제';

    return '${createdAt.month}월 ${createdAt.day}일';
  }

  static Color _colorFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.schedule:
        return const Color(0xFF4A90E2);
      case AppNotificationType.settlement:
        return const Color(0xFFFFB020);
      case AppNotificationType.reminder:
        return const Color(0xFFFFD54F);
      case AppNotificationType.general:
        return const Color(0xFF8E8E93);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Color color;
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.color,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF242424),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
