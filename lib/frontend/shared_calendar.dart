// lib/frontend/shared_calendar.dart

import 'package:flutter/material.dart';
import 'place_candidates.dart';

// 공용 캘린더 / 빈 시간 확인 — REQ-F-04, F-05
class SharedCalendarScreen extends StatelessWidget {
  final String meetingTitle;
  final String meetingEmoji;

  const SharedCalendarScreen({
    super.key,
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
  });

  static const Set<int> bestDays = {10};
  static const Set<int> goodDays = {4, 5, 7, 8, 11};
  static const Set<int> normalDays = {9, 16, 17, 18};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommonTimeBanner(),
                    const SizedBox(height: 24),
                    _buildWeekdayRow(),
                    const SizedBox(height: 8),
                    _buildCalendarGrid(),
                    const SizedBox(height: 24),
                    const Text(
                      '참여자별 가능 현황',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _ParticipantBar(name: '나', days: 3, ratio: 0.75, color: Color(0xFFC8F5E5)),
                    const _ParticipantBar(name: 'A', days: 4, ratio: 0.95, color: Color(0xFFD8FFB8)),
                    const _ParticipantBar(name: 'B', days: 2, ratio: 0.55, color: Color(0xFFFFEBD1)),
                    const SizedBox(height: 24),
                    _buildNextButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Text(
            '공용 캘린더',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonTimeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF294C7A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$meetingEmoji $meetingTitle',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '공통 가능 시간',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '4월 10일 오전 · 5명 모두 가능',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    const leadingEmptyCount = 2;
    const daysInMonth = 30;
    const totalCells = 35;

    return GridView.builder(
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        if (index < leadingEmptyCount) return const SizedBox.shrink();
        final day = index - leadingEmptyCount + 1;
        if (day > daysInMonth) return const SizedBox.shrink();

        Color backgroundColor = Colors.transparent;
        Color textColor = Colors.white;
        if (bestDays.contains(day)) {
          backgroundColor = const Color(0xFF4A6CF7);
        } else if (goodDays.contains(day)) {
          backgroundColor = const Color(0xFF004D40);
        } else if (normalDays.contains(day)) {
          backgroundColor = const Color(0xFF7A4B00);
        }

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: bestDays.contains(day) ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceCandidatesScreen(
                meetingTitle: meetingTitle,
                meetingEmoji: meetingEmoji,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A6CF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text(
          '장소 후보 보러가기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ParticipantBar extends StatelessWidget {
  final String name;
  final int days;
  final double ratio;
  final Color color;

  const _ParticipantBar({
    required this.name,
    required this.days,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: const Color(0xFF3A3A3C),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$days일',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
