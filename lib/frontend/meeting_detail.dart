import 'package:flutter/material.dart';
import 'schedule_input.dart';
import 'shared_calendar.dart';
import 'place_candidates.dart';
import 'settlement.dart';
import 'package:flutter/services.dart';

// 홈에서 모임 카드를 눌렀을 때 들어오는 모임별 기능 허브 화면
class MeetingDetailScreen extends StatelessWidget {
  final String docID;
  final String emoji;
  final String title;
  final int participantCount;
  final String date;
  final String statusText;
  final bool hasWarning;
  final String? warningMessage;

  const MeetingDetailScreen({
    super.key,
    required this.docID,
    required this.emoji,
    required this.title,
    required this.participantCount,
    required this.date,
    required this.statusText,
    required this.hasWarning,
    this.warningMessage,
  });

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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeetingSummary(context),
                    const SizedBox(height: 24),
                    const Text(
                      '모임 기능',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      icon: Icons.edit_calendar_rounded,
                      title: '일정 입력',
                      description: '내가 가능한 날짜와 시간대를 입력합니다.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduleInputScreen(
                              docID: docID,
                              meetingTitle: title,
                              meetingEmoji: emoji,
                            ),
                          ),
                        );
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.calendar_month_rounded,
                      title: '공용 캘린더',
                      description: '참여자별 가능 시간을 모아보고 최적 날짜를 확인합니다.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SharedCalendarScreen(
                              docID: docID,
                              meetingTitle: title,
                              meetingEmoji: emoji,
                            ),
                          ),
                        );
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.place_rounded,
                      title: '장소 후보',
                      description: '장소 후보를 확인하고 투표합니다.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaceCandidatesScreen(
                              meetingTitle: title,
                              meetingEmoji: emoji,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.payments_rounded,
                      title: '정산',
                      description: '총 지출 금액을 입력하고 1/N 금액을 계산합니다.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettlementScreen(
                              meetingTitle: title,
                              meetingEmoji: emoji,
                              participantCount: participantCount,
                            ),
                          ),
                        );
                      },
                    ),
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
            '모임 상세',
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

  Widget _buildMeetingSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '참여자 $participantCount명 · $date · $statusText',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF3A3A3C), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '초대 코드',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    docID,
                    style: const TextStyle(
                      color: Color(0xFF4A6CF7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: docID));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('초대 코드가 복사되었습니다!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7).withOpacity(0.2),
                  foregroundColor: const Color(0xFF4A6CF7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('복사'),
              ),
            ],
          ),

          if (hasWarning && warningMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.20),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                warningMessage!,
                style: const TextStyle(
                  color: Color(0xFFFFB74D),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A3A3C)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF4A6CF7), size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
