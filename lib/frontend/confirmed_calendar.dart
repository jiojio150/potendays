import 'package:flutter/material.dart';

// 하단 캘린더 탭 전용: 각 모임의 확정 일정 표시
class ConfirmedCalendarScreen extends StatefulWidget {
  const ConfirmedCalendarScreen({super.key});

  @override
  State<ConfirmedCalendarScreen> createState() => _ConfirmedCalendarScreenState();
}

class _ConfirmedCalendarScreenState extends State<ConfirmedCalendarScreen> {
  DateTime _focusedMonth = DateTime(2025, 4, 1);
  DateTime _selectedDate = DateTime(2025, 4, 10);

  final Map<String, List<_ConfirmedEvent>> _events = {
    '2025-03-28': [
      _ConfirmedEvent(
        emoji: '🍔',
        title: '팀 회식',
        time: '오후 7:00',
        place: '합정 고깃집',
      ),
    ],
    '2025-04-10': [
      _ConfirmedEvent(
        emoji: '🎉',
        title: '종강 파티',
        time: '오후 6:00',
        place: '홍대입구 곱창집',
      ),
    ],
  };

  final List<_PendingMeeting> _pendingMeetings = const [
    _PendingMeeting(
      emoji: '🎮',
      title: '게임 모임',
      status: '날짜/장소 조율 중',
    ),
  ];

  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _events[_dateKey(_selectedDate)] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroCard(),
                    const SizedBox(height: 22),
                    _buildMonthHeader(),
                    const SizedBox(height: 14),
                    _buildWeekdayRow(),
                    const SizedBox(height: 10),
                    _buildCalendarGrid(),
                    const SizedBox(height: 26),
                    _buildSelectedDateSection(selectedEvents),
                    const SizedBox(height: 26),
                    _buildPendingMeetingsSection(),
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
            '캘린더',
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

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 모임 확정 일정',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '각 모임에서 확정된 날짜, 시간, 장소를 한 번에 확인합니다.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
        ),
        Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    return Row(
      children: _weekdays.map((day) {
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
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingEmptyCount = firstDay.weekday % 7;
    final totalCells = ((leadingEmptyCount + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        if (index < leadingEmptyCount) return const SizedBox.shrink();
        final day = index - leadingEmptyCount + 1;
        if (day > daysInMonth) return const SizedBox.shrink();

        final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
        final key = _dateKey(date);
        final hasEvent = _events.containsKey(key);
        final isSelected = _isSameDate(date, _selectedDate);

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4A6CF7).withOpacity(0.24)
                  : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF4A6CF7) : const Color(0xFF3A3A3C),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF83A5FF) : Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasEvent)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A6CF7),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 7),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDateSection(List<_ConfirmedEvent> selectedEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate.month}월 ${_selectedDate.day}일 일정',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (selectedEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A3A3C)),
            ),
            child: const Text(
              '이 날짜에는 확정된 일정이 없습니다.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          ...selectedEvents.map(
                (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CalendarEventCard(event: event),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingMeetingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '미정 일정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._pendingMeetings.map(
              (meeting) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB020)),
            ),
            child: Row(
              children: [
                Text(meeting.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        meeting.status,
                        style: const TextStyle(
                          color: Color(0xFFFFB020),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFFFB020)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CalendarEventCard extends StatelessWidget {
  final _ConfirmedEvent event;

  const _CalendarEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(event.time, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(event.place, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF4A6CF7)),
        ],
      ),
    );
  }
}

class _ConfirmedEvent {
  final String emoji;
  final String title;
  final String time;
  final String place;

  const _ConfirmedEvent({
    required this.emoji,
    required this.title,
    required this.time,
    required this.place,
  });
}

class _PendingMeeting {
  final String emoji;
  final String title;
  final String status;

  const _PendingMeeting({
    required this.emoji,
    required this.title,
    required this.status,
  });
}
