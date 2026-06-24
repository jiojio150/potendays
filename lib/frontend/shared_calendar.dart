import 'package:flutter/material.dart';
import '../services/schedule_service.dart';
import '../models/schedule_model.dart';
import 'place_candidates.dart';

class SharedCalendarScreen extends StatefulWidget {
  final String docID;
  final String meetingTitle;
  final String meetingEmoji;

  const SharedCalendarScreen({
    super.key,
    required this.docID,
    required this.meetingTitle,
    required this.meetingEmoji,
  });

  @override
  State<SharedCalendarScreen> createState() => _SharedCalendarScreenState();
}

class _SharedCalendarScreenState extends State<SharedCalendarScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  static const List<String> _timeOrder = ['오전', '오후', '저녁'];

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedDay = DateTime.now().day;

  // 추천 날짜로 자동 이동은 처음 1번만 해야 함
  // 이 값이 없으면 사용자가 달 이동 버튼을 눌러도 계속 추천 날짜로 되돌아감
  bool _isInitialLoaded = false;

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _selectedDay = 1;
    });
  }

  String _getDateKey(int day) {
    return "${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }

  CalendarData _processData(List<ScheduleModel> schedules) {
    final Map<int, Map<String, int>> dayTimeCounts = {};
    final Map<String, Map<String, List<String>>> detailsByDate = {};

    for (var schedule in schedules) {
      final String name = schedule.userName.trim().isNotEmpty
          ? schedule.userName.trim()
          : schedule.uid;
      final timeMap = schedule.timeSelection;

      timeMap.forEach((dateKey, times) {
        detailsByDate.putIfAbsent(dateKey, () => {});
        detailsByDate[dateKey]![name] = times;

        try {
          final date = DateTime.parse(dateKey);

          if (date.year == _focusedMonth.year && date.month == _focusedMonth.month) {
            final day = date.day;

            dayTimeCounts.putIfAbsent(
              day,
              () => {'오전': 0, '오후': 0, '저녁': 0},
            );

            for (var time in times) {
              if (dayTimeCounts[day]!.containsKey(time)) {
                dayTimeCounts[day]![time] = dayTimeCounts[day]![time]! + 1;
              }
            }
          }
        } catch (e) {
          debugPrint("날짜 파싱 에러: $e");
        }
      });
    }

    return CalendarData(dayTimeCounts, detailsByDate);
  }

  void _moveToBestDateOnce(CalendarData processed) {
    if (_isInitialLoaded || processed.detailsByDate.isEmpty) return;

    String? bestDateKey;
    int bestCount = 0;

    processed.detailsByDate.forEach((dateKey, users) {
      final Map<String, int> timeCounts = {'오전': 0, '오후': 0, '저녁': 0};

      for (final times in users.values) {
        for (final time in times) {
          if (timeCounts.containsKey(time)) {
            timeCounts[time] = timeCounts[time]! + 1;
          }
        }
      }

      final int dateBestCount = timeCounts.values.fold(0, (max, count) {
        return count > max ? count : max;
      });

      if (dateBestCount > bestCount) {
        bestCount = dateBestCount;
        bestDateKey = dateKey;
      }
    });

    if (bestDateKey == null || bestCount == 0) {
      _isInitialLoaded = true;
      return;
    }

    final bestDate = DateTime.parse(bestDateKey!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isInitialLoaded) return;

      setState(() {
        _focusedMonth = DateTime(bestDate.year, bestDate.month, 1);
        _selectedDay = bestDate.day;
        _isInitialLoaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A071E),
      body: StreamBuilder<List<ScheduleModel>>(
        stream: _scheduleService.getGroupSchedulesStream(widget.docID),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("에러가 발생했습니다.", style: TextStyle(color: Colors.white)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("아직 등록된 일정이 없습니다.", style: TextStyle(color: Colors.white)),
            );
          }

          final List<ScheduleModel> schedules = snapshot.data!;
          final processed = _processData(schedules);
          final int totalParticipants = schedules.length;

          _moveToBestDateOnce(processed);

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildCommonTimeBanner(processed.dayTimeCounts),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_focusedMonth.year}년 ${_focusedMonth.month}월",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _moveMonth(-1),
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                            ),
                            IconButton(
                              onPressed: () => _moveMonth(1),
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildWeekdayRow(),
                    const SizedBox(height: 8),
                    _buildSharedCalendarGrid(processed.dayTimeCounts, totalParticipants),
                    const SizedBox(height: 32),

                    Text(
                      '${_focusedMonth.month}월 $_selectedDay일 가능한 사람',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildParticipantList(processed.detailsByDate[_getDateKey(_selectedDay)] ?? {}),
                    const SizedBox(height: 32),
                    _buildNextButton(context),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const Text(
            '공유 캘린더',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonTimeBanner(Map<int, Map<String, int>> dayTimeCounts) {
    int bestDay = 0;
    int maxVotes = 0;
    List<String> bestTimes = [];

    dayTimeCounts.forEach((day, times) {
      times.forEach((time, count) {
        if (count > maxVotes) {
          maxVotes = count;
          bestDay = day;
          bestTimes = [time];
        } else if (count == maxVotes && maxVotes > 0 && bestDay == day) {
          bestTimes.add(time);
        }
      });
    });

    final List<String> orderedBestTimes = _timeOrder
        .where((time) => bestTimes.contains(time))
        .toList();

    final String timeResult = orderedBestTimes.length == _timeOrder.length
        ? "모두"
        : orderedBestTimes.join(', ');

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
            '${widget.meetingEmoji} ${widget.meetingTitle}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '가장 추천하는 시간',
            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            maxVotes > 0
                ? '${_focusedMonth.month}월 $bestDay일 $timeResult 가능 · $maxVotes명 🔥'
                : '모두의 일정을 기다리고 있어요!',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Row(
      children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSharedCalendarGrid(
    Map<int, Map<String, int>> dayTimeCounts,
    int totalParticipants,
  ) {
    final int firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    return GridView.builder(
      itemCount: 42,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

        final isSelected = day == _selectedDay;
        final counts = dayTimeCounts[day] ?? {'오전': 0, '오후': 0, '저녁': 0};

        final int dayMaxVotes = counts.values.fold(0, (max, count) {
          return count > max ? count : max;
        });

        final double ratio = totalParticipants > 0 ? dayMaxVotes / totalParticipants : 0;

        final Color cellColor = ratio > 0
            ? const Color(0xFF4A6CF7).withOpacity(ratio.clamp(0.1, 1.0))
            : const Color(0xFF3A3A3C);

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = day),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: ratio > 0.5 ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeStatus(List<String> times) {
    final List<String> orderedTimes = _timeOrder
        .where((time) => times.contains(time))
        .toList();

    if (orderedTimes.isEmpty) return "불가능";
    if (orderedTimes.length == _timeOrder.length) return "모두 가능";

    return "${orderedTimes.join(', ')} 가능";
  }

  Widget _buildParticipantList(Map<String, List<String>> participants) {
    if (participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('가능한 인원이 없습니다.', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: participants.entries.map((e) {
        final String status = _formatTimeStatus(e.value);

        return _ParticipantBar(
          name: e.key,
          timeStatus: status,
          color: const Color(0xFFE2E2E2),
        );
      }).toList(),
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
                meetingId: widget.docID,
                meetingTitle: widget.meetingTitle,
                meetingEmoji: widget.meetingEmoji,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A6CF7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

class CalendarData {
  final Map<int, Map<String, int>> dayTimeCounts;
  final Map<String, Map<String, List<String>>> detailsByDate;

  CalendarData(this.dayTimeCounts, this.detailsByDate);
}

class _ParticipantBar extends StatelessWidget {
  final String name;
  final String timeStatus;
  final Color color;

  const _ParticipantBar({
    required this.name,
    required this.timeStatus,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty ? name[0] : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name $timeStatus',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
