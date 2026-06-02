// lib/frontend/notifications.dart

import 'package:flutter/material.dart';

// 알림 센터 — REQ-F-09
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const List<NotificationItem> notifications = [
    NotificationItem(
      section: '오늘',
      color: Color(0xFF4A90E2),
      title: '🗓 모임 일정 알림',
      message: '종강 파티가 2일 후입니다 (4월 4일 오전)',
      time: '방금 전',
      type: NotificationType.schedule,
    ),
    NotificationItem(
      section: '오늘',
      color: Color(0xFFFFB020),
      title: '💸 정산 요청',
      message: '팀 회식 정산 입력이 필요합니다',
      time: '1시간 전',
      type: NotificationType.settlement,
    ),
    NotificationItem(
      section: '어제',
      color: Color(0xFFFFD54F),
      title: '🔔 리마인드',
      message: '게임 모임 일정이 아직 미입력 상태입니다',
      time: '어제 오후 3시',
      type: NotificationType.reminder,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                children: [
                  _SectionLabel(label: '오늘'),
                  const SizedBox(height: 12),

                  ...notifications
                      .where((notification) => notification.section == '오늘')
                      .map(
                        (notification) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _NotificationCard(
                            color: notification.color,
                            title: notification.title,
                            message: notification.message,
                            time: notification.time,
                            onTap: () {
                              _handleNotificationTap(context, notification);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const _SectionLabel(label: '어제'),
                      const SizedBox(height: 12),

                      ...notifications
                        .where((notification) => notification.section == '어제')
                        .map(
                          (notification) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NotificationCard(
                              color: notification.color,
                              title: notification.title,
                              message: notification.message,
                              time: notification.time,
                              onTap: () {
                                _handleNotificationTap(context, notification);
                              },
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationItem notification,
  ) {
    switch (notification.type) {
      case NotificationType.schedule:
        Navigator.pushNamed(context, '/confirmed-calendar');
        break;
      case NotificationType.settlement:
        Navigator.pushNamed(context, '/settlement');
        break;
      case NotificationType.reminder:
        Navigator.pushNamed(context, '/schedule-input');
        break;
    }
  }

  Widget _buildHeader(BuildContext context) {
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
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.color,
    required this.title,
    required this.message,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
      ),
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
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

class NotificationItem {
  final String section;
  final Color color;
  final String title;
  final String message;
  final String time;
  final NotificationType type;

  const NotificationItem({
    required this.section,
    required this.color,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
  });
}

enum NotificationType { schedule, settlement, reminder }
