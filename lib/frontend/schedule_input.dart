import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/schedule_service.dart';
import '../models/schedule_model.dart';
import 'shared_calendar.dart';

class ScheduleInputScreen extends StatefulWidget {
  final String docID;
  final String meetingTitle;
  final String meetingEmoji;

  const ScheduleInputScreen({
    super.key,
    required this.docID,
    required this.meetingTitle,
    required this.meetingEmoji,
  });

  @override
  State<ScheduleInputScreen> createState() => _ScheduleInputScreenState();
}

class _ScheduleInputScreenState extends State<ScheduleInputScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1); 
  Map<String, Set<String>> _selectedDayTimes = {}; 
  int _selectedDay = DateTime.now().day;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingSchedule();
  }

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _selectedDay = 1;
    });
  }

  String _getDateKey(int day) {
    return "${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }

  void _loadExistingSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final schedule = await _scheduleService.getUserSchedule(widget.docID, uid);

      if (schedule != null) {
        setState(() {
          _selectedDayTimes = schedule.timeSelection.map(
            (key, value) => MapEntry(key, Set<String>.from(value)),
          );
        });
      }
    } catch (e) {
      debugPrint("데이터 불러오기 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleDay(int day) {
    setState(() {
      _selectedDay = day;
      String key = _getDateKey(day);
      _selectedDayTimes.putIfAbsent(key, () => <String>{});
    });
  }

  void _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? '이름 없음');

    setState(() => _isLoading = true);

    try {
      final newSchedule = ScheduleModel(
        uid: uid,
        userName: userName,
        timeSelection: _selectedDayTimes.map((key, value) => MapEntry(key, value.toList())),
      );

      await _scheduleService.saveUserSchedule(
        docID: widget.docID,
        schedule: newSchedule,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 저장되었습니다! 😊')),
        );

        Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SharedCalendarScreen(
              docID: widget.docID,
              meetingTitle: widget.meetingTitle,
              meetingEmoji: widget.meetingEmoji,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했습니다. 😢')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1C1C1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A6CF7))),
      );
    }

    final int firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // 시작 요일
    final int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day; // 총 일수

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
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 26),
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
                    _buildCalendarGrid(firstWeekday, daysInMonth),
                    const SizedBox(height: 18),
                    _buildLegend(),
                    const SizedBox(height: 24),
                    Text('가능 시간대 (${_focusedMonth.month}월 $_selectedDay일)', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5))),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          const Text('내 일정 입력', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() => Row(children: const ['일', '월', '화', '수', '목', '금', '토'].map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600))))).toList());

  Widget _buildCalendarGrid(int firstWeekday, int daysInMonth) {
    return GridView.builder(
      itemCount: 42,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.15),
      itemBuilder: (context, index) {
        final int day = index - firstWeekday + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

        final String dateKey = _getDateKey(day);
        final isSelected = day == _selectedDay;
        final dayTimes = _selectedDayTimes[dateKey] ?? {}; 

        Color bgColor = Colors.transparent;
        if (dayTimes.length == 3) {
          bgColor = const Color(0xFF004D40); 
        } else if (dayTimes.isNotEmpty) {
          bgColor = const Color(0xFF7A4B00);
        }

        return GestureDetector(
          onTap: () => _toggleDay(day), 
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected ? const Color(0xFF4A6CF7) : Colors.transparent, 
                width: 2,
              ),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? const Color(0xFF83A5FF) : Colors.white, 
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() => Row(children: const [_LegendItem(color: Color(0xFF004D40), label: '가능'), SizedBox(width: 18), _LegendItem(color: Color(0xFF7A4B00), label: '일부 가능')]);

  Widget _buildTimeToggles() {
    final times = ['오전', '오후', '저녁'];
    final String dateKey = _getDateKey(_selectedDay);
    final currentDayTimes = _selectedDayTimes[dateKey] ?? {};
    
    return Row(children: times.map((time) {
      final isChecked = currentDayTimes.contains(time);
      return Padding(padding: const EdgeInsets.only(right: 10), child: GestureDetector(
        onTap: () => setState(() {
          if (!_selectedDayTimes.containsKey(dateKey)) {
            _selectedDayTimes[dateKey] = <String>{};
          }
          final currentDaySet = _selectedDayTimes[dateKey]!;
          if (isChecked) {
            currentDaySet.remove(time);
          } else {
            currentDaySet.add(time);
          }
        }),
        child: Container(width: 64, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: isChecked ? const Color(0xFF4A6CF7).withOpacity(0.25) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isChecked ? const Color(0xFF4A6CF7) : const Color(0xFF3A3A3C))), child: Text(time, style: TextStyle(color: isChecked ? const Color(0xFF83A5FF) : Colors.white70, fontWeight: FontWeight.bold))),
      ));
    }).toList());
  }

  Widget _buildSaveButton() => SizedBox(width: double.infinity, height: 58, child: OutlinedButton(onPressed: _saveSchedule, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('일정 저장', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))));
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))]);
}