// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:potendays/frontend/create_meeting.dart';

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
// 홈 / 모임 목록 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  // 샘플 데이터
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단 헤더 ──
            _buildHeader(),

            const SizedBox(height: 8),

            // ── 모임 카드 리스트 ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _meetings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _MeetingCard(meeting: _meetings[index]);
                },
              ),
            ),
          ],
        ),
      ),

      // ── 하단 탭 네비게이션 ──
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ── 헤더 (내 모임 + 생성 버튼) ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
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
              // TODO: 모임 생성 화면으로 이동
            },
          ),
        ],
      ),
    );
  }

  // ── 하단 탭 네비게이션 ──
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
                  onTap: () => setState(() => _currentTabIndex = index),
                  behavior: HitTestBehavior.opaque,
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// + 생성 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _CreateButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateMeetingScreen(),
        ),
      );
    },
    icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        '생성',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white38, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 모임 카드 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단: 이모지 + 제목 + 뱃지 ──
          Row(
            children: [
              Text(
                meeting.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meeting.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              _StatusBadge(status: meeting.status),
            ],
          ),

          const SizedBox(height: 6),

          // ── 하단: 참여자 수 · 날짜 ──
          Text(
            '참여자 ${meeting.participantCount}명 · ${meeting.date}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),

          // ── 경고 태그 (일정 미입력 등) ──
          if (meeting.hasWarning && meeting.warningMessage != null) ...[
            const SizedBox(height: 10),
            _WarningTag(message: meeting.warningMessage!),
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 상태 뱃지 (진행중 / 완료)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _StatusBadge extends StatelessWidget {
  final MeetingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isInProgress = status == MeetingStatus.inProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isInProgress
            ? const Color(0xFF4A6CF7).withOpacity(0.2)
            : const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInProgress
              ? const Color(0xFF4A6CF7).withOpacity(0.6)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Text(
        isInProgress ? '진행중' : '완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isInProgress
              ? const Color(0xFF4A6CF7)
              : Colors.white54,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 경고 태그 (일정 미입력 등)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _WarningTag extends StatelessWidget {
  final String message;

  const _WarningTag({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB800).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFB800).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFFFB800),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}