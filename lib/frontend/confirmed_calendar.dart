import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 하단 캘린더 탭 전용:
// 현재 사용자가 참여 중인 모임 가운데 확정된 일정만 표시한다.
class ConfirmedCalendarScreen extends StatefulWidget {
  const ConfirmedCalendarScreen({super.key});

  @override
  State<ConfirmedCalendarScreen> createState() =>
      _ConfirmedCalendarScreenState();
}

class _ConfirmedCalendarScreenState
    extends State<ConfirmedCalendarScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  static const List<String> _weekdays = [
    '일',
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchMyMeetings(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('meetings')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  List<_ConfirmedEvent> _extractConfirmedEvents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<_ConfirmedEvent> events = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final bool isConfirmed = data['isConfirmed'] == true;
      final Object? confirmedValue = data['confirmedDateTime'];

      // 확정 여부가 true이고 확정 일시가 실제로 저장된 모임만 표시한다.
      if (!isConfirmed || confirmedValue is! Timestamp) {
        continue;
      }

      final DateTime confirmedDateTime =
          confirmedValue.toDate().toLocal();

      final String placeName =
          (data['confirmedPlaceName'] as String?)?.trim() ?? '';

      final String placeAddress =
          (data['confirmedPlaceAddress'] as String?)?.trim() ?? '';

      events.add(
        _ConfirmedEvent(
          meetingId: document.id,
          emoji: (data['emoji'] as String?)?.trim().isNotEmpty == true
              ? (data['emoji'] as String).trim()
              : '📍',
          title: (data['title'] as String?)?.trim().isNotEmpty == true
              ? (data['title'] as String).trim()
              : '이름 없는 모임',
          dateTime: confirmedDateTime,
          placeName: placeName,
          placeAddress: placeAddress,
        ),
      );
    }

    events.sort(
      (_ConfirmedEvent a, _ConfirmedEvent b) =>
          a.dateTime.compareTo(b.dateTime),
    );

    return events;
  }

  Map<String, List<_ConfirmedEvent>> _groupEventsByDate(
    List<_ConfirmedEvent> events,
  ) {
    final Map<String, List<_ConfirmedEvent>> grouped = {};

    for (final _ConfirmedEvent event in events) {
      final String key = _dateKey(event.dateTime);
      grouped.putIfAbsent(key, () => <_ConfirmedEvent>[]).add(event);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: currentUser == null
                  ? _buildLoginRequired()
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _watchMyMeetings(currentUser.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          debugPrint(
                            '확정 일정 조회 오류: ${snapshot.error}',
                          );

                          return _buildErrorState();
                        }

                        final List<_ConfirmedEvent> events =
                            snapshot.hasData
                                ? _extractConfirmedEvents(snapshot.data!)
                                : <_ConfirmedEvent>[];

                        final Map<String, List<_ConfirmedEvent>>
                            eventsByDate = _groupEventsByDate(events);

                        final List<_ConfirmedEvent> selectedEvents =
                            eventsByDate[_dateKey(_selectedDate)] ??
                                <_ConfirmedEvent>[];

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            28,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _buildIntroCard(events.length),
                              const SizedBox(height: 22),
                              _buildMonthHeader(),
                              const SizedBox(height: 14),
                              _buildWeekdayRow(),
                              const SizedBox(height: 10),
                              _buildCalendarGrid(eventsByDate),
                              const SizedBox(height: 26),
                              _buildSelectedDateSection(
                                selectedEvents,
                              ),
                            ],
                          ),
                        );
                      },
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
          bottom: BorderSide(
            color: Color(0xFF3A3A3C),
            width: 0.5,
          ),
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

  Widget _buildIntroCard(int eventCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3A3A3C),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 모임 확정 일정',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '날짜, 시간, 장소가 최종 확정된 모임만 달력에 표시됩니다.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '확정 일정 $eventCount개',
            style: const TextStyle(
              color: Color(0xFF83A5FF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 30,
          ),
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
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    return Row(
      children: _weekdays.map((String day) {
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

  Widget _buildCalendarGrid(
    Map<String, List<_ConfirmedEvent>> eventsByDate,
  ) {
    final DateTime firstDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );

    final int daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;

    final int leadingEmptyCount = firstDay.weekday % 7;

    final int totalCells =
        ((leadingEmptyCount + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        if (index < leadingEmptyCount) {
          return const SizedBox.shrink();
        }

        final int day = index - leadingEmptyCount + 1;

        if (day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final DateTime date = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          day,
        );

        final String key = _dateKey(date);
        final bool hasConfirmedEvent =
            (eventsByDate[key]?.isNotEmpty ?? false);
        final bool isSelected =
            _isSameDate(date, _selectedDate);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4A6CF7).withOpacity(0.24)
                  : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4A6CF7)
                    : const Color(0xFF3A3A3C),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF83A5FF)
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasConfirmedEvent)
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

  Widget _buildSelectedDateSection(
    List<_ConfirmedEvent> selectedEvents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate.month}월 ${_selectedDate.day}일 확정 일정',
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
              border: Border.all(
                color: const Color(0xFF3A3A3C),
              ),
            ),
            child: const Text(
              '이 날짜에는 확정된 일정이 없습니다.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          )
        else
          ...selectedEvents.map(
            (_ConfirmedEvent event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CalendarEventCard(event: event),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginRequired() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          '확정 일정을 확인하려면 Google/Firebase 로그인이 필요합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          '확정 일정을 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + offset,
        1,
      );

      _selectedDate = DateTime(
        _focusedMonth.year,
        _focusedMonth.month,
        1,
      );
    });
  }

  String _dateKey(DateTime date) {
    final String month =
        date.month.toString().padLeft(2, '0');

    final String day =
        date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _CalendarEventCard extends StatelessWidget {
  final _ConfirmedEvent event;

  const _CalendarEventCard({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final String placeText = event.placeAddress.isEmpty
        ? event.placeName
        : event.placeName.isEmpty
            ? event.placeAddress
            : '${event.placeName}\n${event.placeAddress}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF3A3A3C),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.emoji,
            style: const TextStyle(fontSize: 24),
          ),
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
                Text(
                  _formatTime(event.dateTime),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  placeText.isEmpty
                      ? '장소 정보 없음'
                      : placeText,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4A6CF7),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    final String period = hour < 12 ? '오전' : '오후';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$period $displayHour:$minute';
  }
}

class _ConfirmedEvent {
  final String meetingId;
  final String emoji;
  final String title;
  final DateTime dateTime;
  final String placeName;
  final String placeAddress;

  const _ConfirmedEvent({
    required this.meetingId,
    required this.emoji,
    required this.title,
    required this.dateTime,
    required this.placeName,
    required this.placeAddress,
  });
}
