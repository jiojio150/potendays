import 'package:flutter/material.dart';
import 'place_candidates.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

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
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedDay = DateTime.now().day;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService().getGroupAvailability(widget.docID),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          int totalParticipants = docs.length;

          Map<int, Map<String, int>> dayTimeCounts = {};
          Map<String, Map<String, List<String>>> detailsByDate = {};
          
          Map<String, int> dateScore = {}; 

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['userName'] ?? '익명';
            final timeMap = data['timeSelection'] as Map<String, dynamic>? ?? {};

            timeMap.forEach((dateKey, times) {
              try {
                DateTime date = dateKey.contains('-') 
                    ? DateTime.parse(dateKey) 
                    : DateTime(2025, 4, int.parse(dateKey));

                if ((times as List).isNotEmpty) {
                  dateScore[dateKey] = (dateScore[dateKey] ?? 0) + 1;
                }

                if (date.year == _focusedMonth.year && date.month == _focusedMonth.month) {
                  int day = date.day;
                  dayTimeCounts.putIfAbsent(day, () => {'오전': 0, '오후': 0, '저녁': 0});
                  for (var t in times) {
                    String timeStr = t.toString();
                    if (dayTimeCounts[day]!.containsKey(timeStr)) {
                      dayTimeCounts[day]![timeStr] = dayTimeCounts[day]![timeStr]! + 1;
                    }
                  }
                  String normalizedKey = _getDateKey(day);
                  detailsByDate.putIfAbsent(normalizedKey, () => {});
                  detailsByDate[normalizedKey]![name] = List<String>.from(times);
                }
              } catch (e) {
                debugPrint("파싱 에러: $e");
              }
            });
          }

          if (!_isInitialLoaded && dateScore.isNotEmpty) {
            String bestDateKey = dateScore.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
            
            DateTime bestDate = DateTime.parse(bestDateKey);
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _focusedMonth = DateTime(bestDate.year, bestDate.month, 1);
                  _selectedDay = bestDate.day;
                  _isInitialLoaded = true;
                });
              }
            });
          }

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommonTimeBanner(dayTimeCounts),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left, color: Colors.white)),
                                IconButton(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildWeekdayRow(),
                        const SizedBox(height: 8),
                        _buildSharedCalendarGrid(dayTimeCounts, totalParticipants),
                        const SizedBox(height: 32),
                        Text(
                          '${_focusedMonth.month}월 ${_selectedDay}일 가능한 사람',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        _buildParticipantList(detailsByDate[_getDateKey(_selectedDay)] ?? {}),
                        const SizedBox(height: 32),
                        _buildNextButton(context),
                      ],
                    ),
                  ),
                ),
              ],
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
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          const Text('공유 캘린더', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCommonTimeBanner(Map<int, Map<String, int>> dayTimeCounts) {
    int bestDay = 0; int maxVotes = 0; List<String> bestTimes = [];
    dayTimeCounts.forEach((day, times) {
      times.forEach((time, count) {
        if (count > maxVotes) {
          maxVotes = count; bestDay = day; bestTimes = [time];
        } else if (count == maxVotes && maxVotes > 0) {
          if (bestDay == day) bestTimes.add(time);
        }
      });
    });
    String timeResult = bestTimes.length >= 3 ? "모두" : bestTimes.join(', ');
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF294C7A), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.meetingEmoji} ${widget.meetingTitle}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('가장 추천하는 시간', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            maxVotes > 0 ? '${_focusedMonth.month}월 $bestDay일 $timeResult 가능 · $maxVotes명 🔥' : '모두의 일정을 기다리고 있어요!',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() => Row(children: ['일', '월', '화', '수', '목', '금', '토'].map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(color: Colors.white54, fontSize: 13))))).toList());

  Widget _buildSharedCalendarGrid(Map<int, Map<String, int>> dayTimeCounts, int totalParticipants) {
    final int firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    return GridView.builder(
      itemCount: 42,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.15
      ),
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

        final isSelected = day == _selectedDay;
        final counts = dayTimeCounts[day] ?? {'오전': 0, '오후': 0, '저녁': 0};
        
        int dayMaxVotes = counts.values.reduce((a, b) => a > b ? a : b);
        double ratio = totalParticipants > 0 ? dayMaxVotes / totalParticipants : 0;

        Color cellColor = Colors.transparent;
        if (ratio > 0) {
          cellColor = const Color(0xFF4A6CF7).withOpacity(ratio.clamp(0.1, 1.0));
        } else {
          cellColor = const Color(0xFF3A3A3C);
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = day),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Text(
              '$day', 
              style: TextStyle(
                color: ratio > 0.5 ? Colors.white : Colors.white70, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              )
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantList(Map<String, List<String>> participants) {
    if (participants.isEmpty) return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text('가능한 인원이 없습니다.', style: TextStyle(color: Colors.white54)),
    );
    
    return Column(
      children: participants.entries.map((e) {
        String status = e.value.isEmpty ? "불가능" : "${e.value.join(', ')} 가능";
        return _ParticipantBar(name: e.key, timeStatus: status, color: const Color(0xFFE2E2E2));
      }).toList(),
    );
  }

  Widget _buildNextButton(BuildContext context) => SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceCandidatesScreen(meetingTitle: widget.meetingTitle, meetingEmoji: widget.meetingEmoji))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6CF7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('장소 후보 보러가기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))));
}

class _ParticipantBar extends StatelessWidget {
  final String name; final String timeStatus; final Color color;
  const _ParticipantBar({required this.name, required this.timeStatus, required this.color});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [CircleAvatar(radius: 18, backgroundColor: color, child: Text(name[0], style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold))), const SizedBox(width: 12), Expanded(child: Text('$name $timeStatus', style: const TextStyle(color: Colors.white, fontSize: 15)))]));
}