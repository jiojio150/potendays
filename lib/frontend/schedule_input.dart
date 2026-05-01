// lib/frontend/schedule_input.dart

import 'package:flutter/material.dart';
import 'shared_calendar.dart';

// 일정 입력 — REQ-F-03
class ScheduleInputScreen extends StatefulWidget {
  final String meetingTitle;
  final String meetingEmoji;

  const ScheduleInputScreen({
    super.key,
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
  });

  @override
  State<ScheduleInputScreen> createState() => _ScheduleInputScreenState();
}

class _ScheduleInputScreenState extends State<ScheduleInputScreen> {
  final Set<int> _availableDays = {4, 5, 7, 8, 10, 11, 16, 17, 18};
  final Set<int> _partialDays = {9, 15};
  int _selectedDay = 4;
  String _selectedTime = '오전';

  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  void _toggleDay(int day) {
    setState(() {
      _selectedDay = day;
      if (_availableDays.contains(day)) {
        _availableDays.remove(day);
        _partialDays.add(day);
      } else if (_partialDays.contains(day)) {
        _partialDays.remove(day);
      } else {
        _availableDays.add(day);
      }
    });
  }

  void _saveSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일정이 저장되었습니다. 공용 캘린더에 반영됩니다.')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedCalendarScreen(
          meetingTitle: widget.meetingTitle,
          meetingEmoji: widget.meetingEmoji,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.meetingEmoji} ${widget.meetingTitle}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '가능한 날짜와 시간대를 입력해주세요.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      '2025년 4월',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildWeekdayRow(),
                    const SizedBox(height: 8),
                    _buildCalendarGrid(),
                    const SizedBox(height: 18),
                    _buildLegend(),
                    const SizedBox(height: 24),
                    Text(
                      '가능 시간대 (4월 $_selectedDay일)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTimeToggles(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            '내 일정 입력',
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
    // 2025년 4월 1일은 화요일이라 앞에 일/월 빈칸 2개
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

        final isSelected = day == _selectedDay;
        final isAvailable = _availableDays.contains(day);
        final isPartial = _partialDays.contains(day);

        Color backgroundColor = Colors.transparent;
        Color textColor = Colors.white;
        Border? border;

        if (isAvailable) {
          backgroundColor = const Color(0xFF004D40);
        }
        if (isPartial) {
          backgroundColor = const Color(0xFF7A4B00);
        }
        if (isSelected) {
          backgroundColor = const Color(0xFF4A6CF7);
          textColor = Colors.white;
        }
        if (!isAvailable && !isPartial && !isSelected) {
          border = Border.all(color: Colors.transparent);
        }

        return GestureDetector(
          onTap: () => _toggleDay(day),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(9),
              border: border,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      children: const [
        _LegendItem(color: Color(0xFFC8F5E5), label: '가능'),
        SizedBox(width: 18),
        _LegendItem(color: Color(0xFFFFEBD1), label: '일부 가능'),
      ],
    );
  }

  Widget _buildTimeToggles() {
    final times = ['오전', '오후', '저녁'];
    return Row(
      children: times.map((time) {
        final isSelected = _selectedTime == time;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedTime = time),
            child: Container(
              width: 64,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A6CF7).withOpacity(0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4A6CF7)
                      : const Color(0xFF3A3A3C),
                ),
              ),
              child: Text(
                time,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF83A5FF) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: _saveSchedule,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          '일정 저장',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
