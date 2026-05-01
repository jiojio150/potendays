// lib/frontend/home.dart

import 'package:flutter/material.dart';
import 'create_meeting.dart';
import 'meeting_detail.dart';
import 'confirmed_calendar.dart';
import 'notifications.dart';
import 'settings.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 모임 데이터 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum MeetingStatus { inProgress, completed }

class MeetingModel {
  final String emoji;
  final String title;
  final int participantCount;
  final String date;
  final MeetingStatus status;
  final bool hasWarning;
  final String? warningMessage;

  const MeetingModel({
    required this.emoji,
    required this.title,
    required this.participantCount,
    required this.date,
    required this.status,
    this.hasWarning = false,
    this.warningMessage,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 홈 / 모임 목록 화면 — REQ-F-13
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  final List<MeetingModel> _meetings = const [
    MeetingModel(
      emoji: '🎉',
      title: '종강 파티',
      participantCount: 5,
      date: '4월 10일',
      status: MeetingStatus.inProgress,
      hasWarning: true,
      warningMessage: '일정 미입력',
    ),
    MeetingModel(
      emoji: '🍔',
      title: '팀 회식',
      participantCount: 8,
      date: '3월 28일',
      status: MeetingStatus.completed,
    ),
    MeetingModel(
      emoji: '🎮',
      title: '게임 모임',
      participantCount: 3,
      date: '미정',
      status: MeetingStatus.inProgress,
    ),
  ];

  void _openMeetingDetail(MeetingModel meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(
          emoji: meeting.emoji,
          title: meeting.title,
          participantCount: meeting.participantCount,
          date: meeting.date,
          statusText:
          meeting.status == MeetingStatus.inProgress ? '진행중' : '완료',
          hasWarning: meeting.hasWarning,
          warningMessage: meeting.warningMessage,
        ),
      ),
    );
  }

  void _onBottomTabTapped(int index) {
    if (index == 0) {
      setState(() => _currentTabIndex = 0);
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConfirmedCalendarScreen()),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: _meetings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final meeting = _meetings[index];
                  return GestureDetector(
                    onTap: () => _openMeetingDetail(meeting),
                    child: _MeetingCard(meeting: meeting),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '내 모임',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          _CreateButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    const items = [
      {'icon': Icons.home_rounded, 'label': '홈'},
      {'icon': Icons.calendar_month_rounded, 'label': '캘린더'},
      {'icon': Icons.notifications_rounded, 'label': '알림'},
      {'icon': Icons.settings_rounded, 'label': '설정'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        border: Border(
          top: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = _currentTabIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onBottomTabTapped(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index]['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? const Color(0xFF4A6CF7)
                            : Colors.white38,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index]['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? const Color(0xFF4A6CF7)
                              : Colors.white38,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        '생성',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white38, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meeting.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meeting.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _StatusBadge(status: meeting.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '참여자 ${meeting.participantCount}명 · ${meeting.date}',
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          if (meeting.hasWarning && meeting.warningMessage != null) ...[
            const SizedBox(height: 12),
            _WarningTag(message: meeting.warningMessage!),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MeetingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isInProgress = status == MeetingStatus.inProgress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isInProgress
            ? const Color(0xFF4A6CF7).withOpacity(0.20)
            : const Color(0xFF2F7D20).withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isInProgress ? '진행중' : '완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isInProgress ? const Color(0xFF83A5FF) : Colors.lightGreenAccent,
        ),
      ),
    );
  }
}

class _WarningTag extends StatelessWidget {
  final String message;

  const _WarningTag({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFB74D),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
