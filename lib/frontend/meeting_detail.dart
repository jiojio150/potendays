import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/schedule_model.dart';
import '../services/meeting_service.dart';
import '../services/schedule_service.dart';
import '../services/user_service.dart';
import 'confirm_meeting.dart';
import 'invite_share.dart';
import 'place_candidates.dart';
import 'reminder_settings.dart';
import 'schedule_input.dart';
import 'settlement.dart';
import 'shared_calendar.dart';

// REQ-F-13 모임 정보 조회
// 모임 기본 정보, 참여자, 일정 입력 현황, 공통 가능 시간,
// 확정 일정·장소, 최근 정산을 한 화면에서 확인한다.
class MeetingDetailScreen extends StatefulWidget {
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
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final MeetingService _meetingService = MeetingService();
  final ScheduleService _scheduleService = ScheduleService();
  final UserService _userService = UserService();

  String _participantKey = '';
  Future<Map<String, String>>? _participantNamesFuture;

  Future<Map<String, String>> _getParticipantNames(List<String> uids) {
    final String key = uids.join('|');

    if (_participantNamesFuture == null || _participantKey != key) {
      _participantKey = key;
      _participantNamesFuture = _userService.getDisplayNames(uids);
    }

    return _participantNamesFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _meetingService.watchMeeting(widget.docID),
                builder: (context, meetingSnapshot) {
                  if (meetingSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (meetingSnapshot.hasError) {
                    return _buildError(
                      '모임 정보를 불러오지 못했습니다.\n'
                      '${meetingSnapshot.error}',
                    );
                  }

                  final Map<String, dynamic>? meetingData =
                      meetingSnapshot.data?.data();

                  if (meetingData == null) {
                    return _buildError('모임 정보를 찾을 수 없습니다.');
                  }

                  return StreamBuilder<List<ScheduleModel>>(
                    stream: _scheduleService.getGroupSchedulesStream(
                      widget.docID,
                    ),
                    builder: (context, scheduleSnapshot) {
                      final List<ScheduleModel> schedules =
                          scheduleSnapshot.data ?? <ScheduleModel>[];

                      return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('meetings')
                            .doc(widget.docID)
                            .collection('settlements')
                            .doc('latest')
                            .snapshots(),
                        builder: (context, settlementSnapshot) {
                          return _buildContent(
                            meetingData: meetingData,
                            schedules: schedules,
                            settlementData:
                                settlementSnapshot.data?.data(),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required Map<String, dynamic> meetingData,
    required List<ScheduleModel> schedules,
    required Map<String, dynamic>? settlementData,
  }) {
    final String title =
        meetingData['title'] as String? ?? widget.title;
    final String emoji =
        meetingData['emoji'] as String? ?? widget.emoji;
    final String description =
        meetingData['description'] as String? ?? '';
    final String creatorUid =
        meetingData['creatorUid'] as String? ?? '';

    final List<String> participantUids = List<String>.from(
      meetingData['participants'] ?? <String>[],
    );

    final bool isConfirmed =
        meetingData['isConfirmed'] as bool? ?? false;
    final Timestamp? confirmedTimestamp =
        meetingData['confirmedDateTime'] as Timestamp?;
    final String confirmedPlace =
        meetingData['confirmedPlaceName'] as String? ?? '';
    final String confirmedAddress =
        meetingData['confirmedPlaceAddress'] as String? ?? '';

    final Map<String, ScheduleModel> scheduleByUid = <String, ScheduleModel>{
      for (final ScheduleModel schedule in schedules)
        schedule.uid: schedule,
    };

    final int submittedCount = participantUids.where((uid) {
      final ScheduleModel? schedule = scheduleByUid[uid];
      return schedule != null && _hasScheduleInput(schedule);
    }).length;

    final List<String> commonSlots = _calculateCommonSlots(
      participantUids: participantUids,
      scheduleByUid: scheduleByUid,
    );

    final bool currentUserIsCreator =
        FirebaseAuth.instance.currentUser?.uid == creatorUid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMeetingSummary(
            title: title,
            emoji: emoji,
            description: description,
            participantCount: participantUids.length,
            isConfirmed: isConfirmed,
            confirmedTimestamp: confirmedTimestamp,
          ),
          const SizedBox(height: 18),

          if (isConfirmed)
            _buildConfirmedInfo(
              confirmedTimestamp: confirmedTimestamp,
              placeName: confirmedPlace,
              placeAddress: confirmedAddress,
            )
          else
            _buildUnconfirmedInfo(currentUserIsCreator),

          const SizedBox(height: 18),
          _buildScheduleOverview(
            participantCount: participantUids.length,
            submittedCount: submittedCount,
            commonSlots: commonSlots,
          ),
          const SizedBox(height: 18),
          _buildParticipantsSection(
            participantUids: participantUids,
            creatorUid: creatorUid,
            scheduleByUid: scheduleByUid,
          ),
          const SizedBox(height: 18),
          _buildSettlementOverview(settlementData),
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
            icon: Icons.qr_code_2_rounded,
            title: '초대 링크·QR',
            description: '참여자에게 초대 링크나 QR 코드를 공유합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InviteShareScreen(
                    meetingId: widget.docID,
                    meetingTitle: title,
                    meetingEmoji: emoji,
                  ),
                ),
              );
            },
          ),
          _FeatureCard(
            icon: Icons.edit_calendar_rounded,
            title: '일정 입력',
            description: '내가 가능한 날짜와 시간대를 입력합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduleInputScreen(
                    docID: widget.docID,
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
            description: '참여자별 가능 시간과 공통 시간을 확인합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SharedCalendarScreen(
                    docID: widget.docID,
                    meetingTitle: title,
                    meetingEmoji: emoji,
                  ),
                ),
              );
            },
          ),
          _FeatureCard(
            icon: Icons.event_available_rounded,
            title: '날짜·장소 확정',
            description: currentUserIsCreator
                ? '최종 모임 날짜, 시간, 장소를 선택합니다.'
                : '확정된 날짜와 장소를 확인합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConfirmMeetingScreen(
                    meetingId: widget.docID,
                    meetingTitle: title,
                    meetingEmoji: emoji,
                  ),
                ),
              );
            },
          ),
          _FeatureCard(
            icon: Icons.notifications_active_rounded,
            title: '리마인드 설정',
            description: currentUserIsCreator
                ? '일정 임박, 정산 필요, 장기간 미모임 알림 시점을 설정합니다.'
                : '모임의 자동 리마인드 설정을 확인합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReminderSettingsScreen(
                    meetingId: widget.docID,
                    meetingTitle: title,
                    creatorUid: creatorUid,
                  ),
                ),
              );
            },
          ),
          _FeatureCard(
            icon: Icons.place_rounded,
            title: '장소 후보',
            description: '등록된 장소 후보를 확인합니다.',
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
          _FeatureCard(
            icon: Icons.payments_rounded,
            title: '정산',
            description: '총 지출 금액을 입력하고 1/N 금액을 계산합니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettlementScreen(
                    meetingId: widget.docID,
                    meetingTitle: title,
                    meetingEmoji: emoji,
                    participantCount: participantUids.length,
                  ),
                ),
              );
            },
          ),
        ],
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
          const Expanded(
            child: Text(
              '모임 상세',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingSummary({
    required String title,
    required String emoji,
    required String description,
    required int participantCount,
    required bool isConfirmed,
    required Timestamp? confirmedTimestamp,
  }) {
    return _SectionCard(
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
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description.trim(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.people_alt_rounded,
                label: '참여자 $participantCount명',
              ),
              _InfoChip(
                icon: isConfirmed
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                label: isConfirmed ? '일정 확정' : '일정 조율 중',
              ),
              if (confirmedTimestamp != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: _formatDateTime(
                    confirmedTimestamp.toDate(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF3A3A3C), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '초대 코드',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.docID,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8AA4FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: widget.docID),
                  );

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('초대 코드가 복사되었습니다.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('복사'),
              ),
            ],
          ),
          if (widget.hasWarning &&
              widget.warningMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.warningMessage!,
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

  Widget _buildConfirmedInfo({
    required Timestamp? confirmedTimestamp,
    required String placeName,
    required String placeAddress,
  }) {
    return _SectionCard(
      title: '확정된 모임 정보',
      icon: Icons.event_available_rounded,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: '날짜·시간',
            value: confirmedTimestamp == null
                ? '미정'
                : _formatDateTime(confirmedTimestamp.toDate()),
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.place_rounded,
            label: '장소',
            value: placeName.trim().isEmpty ? '미정' : placeName.trim(),
          ),
          if (placeAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.map_rounded,
              label: '상세 위치',
              value: placeAddress.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnconfirmedInfo(bool currentUserIsCreator) {
    return _SectionCard(
      title: '확정된 모임 정보',
      icon: Icons.event_busy_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.white54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentUserIsCreator
                  ? '아직 날짜와 장소가 확정되지 않았습니다. 아래의 '
                      '‘날짜·장소 확정’에서 최종 정보를 선택해 주세요.'
                  : '아직 모임장이 날짜와 장소를 확정하지 않았습니다.',
              style: const TextStyle(
                color: Colors.white60,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleOverview({
    required int participantCount,
    required int submittedCount,
    required List<String> commonSlots,
  }) {
    final bool allSubmitted =
        participantCount > 0 && submittedCount == participantCount;

    return _SectionCard(
      title: '일정 현황',
      icon: Icons.calendar_view_week_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: '일정 입력',
                  value: '$submittedCount/$participantCount명',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: '공통 가능 시간',
                  value: allSubmitted
                      ? '${commonSlots.length}개'
                      : '계산 대기',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!allSubmitted)
            const Text(
              '모든 참여자가 일정을 입력하면 공통 가능 시간을 계산합니다.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            )
          else if (commonSlots.isEmpty)
            const Text(
              '모든 참여자가 공통으로 가능한 시간이 없습니다.',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 13,
              ),
            )
          else ...[
            const Text(
              '추천 공통 시간',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonSlots
                  .take(4)
                  .map(
                    (slot) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A6CF7)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        slot,
                        style: const TextStyle(
                          color: Color(0xFFAFC0FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsSection({
    required List<String> participantUids,
    required String creatorUid,
    required Map<String, ScheduleModel> scheduleByUid,
  }) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return _SectionCard(
      title: '참여자',
      icon: Icons.groups_rounded,
      child: FutureBuilder<Map<String, String>>(
        future: _getParticipantNames(participantUids),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final Map<String, String> names =
              snapshot.data ?? <String, String>{};

          if (participantUids.isEmpty) {
            return const Text(
              '등록된 참여자가 없습니다.',
              style: TextStyle(color: Colors.white54),
            );
          }

          return Column(
            children: [
              for (int index = 0;
                  index < participantUids.length;
                  index++) ...[
                _ParticipantRow(
                  name: names[participantUids[index]] ??
                      '참여자 ${index + 1}',
                  isMe: participantUids[index] == currentUid,
                  isCreator: participantUids[index] == creatorUid,
                  hasSchedule: scheduleByUid[participantUids[index]] != null &&
                      _hasScheduleInput(
                        scheduleByUid[participantUids[index]]!,
                      ),
                ),
                if (index != participantUids.length - 1)
                  const Divider(
                    color: Color(0xFF3A3A3C),
                    height: 20,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettlementOverview(
    Map<String, dynamic>? settlementData,
  ) {
    if (settlementData == null) {
      return const _SectionCard(
        title: '최근 정산',
        icon: Icons.receipt_long_rounded,
        child: Text(
          '아직 저장된 정산 내역이 없습니다.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      );
    }

    final int totalAmount =
        (settlementData['totalAmount'] as num?)?.toInt() ?? 0;
    final int perPersonAmount =
        (settlementData['perPersonAmount'] as num?)?.toInt() ?? 0;
    final Timestamp? updatedAt =
        settlementData['updatedAt'] as Timestamp?;

    return _SectionCard(
      title: '최근 정산',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.payments_rounded,
            label: '총 지출',
            value: '${_formatMoney(totalAmount)}원',
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.person_rounded,
            label: '기본 1인당',
            value: '${_formatMoney(perPersonAmount)}원',
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.update_rounded,
              label: '최근 저장',
              value: _formatDateTime(updatedAt.toDate()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  bool _hasScheduleInput(ScheduleModel schedule) {
    return schedule.timeSelection.values.any(
      (List<String> times) => times.isNotEmpty,
    );
  }

  List<String> _calculateCommonSlots({
    required List<String> participantUids,
    required Map<String, ScheduleModel> scheduleByUid,
  }) {
    if (participantUids.isEmpty) return <String>[];

    for (final String uid in participantUids) {
      final ScheduleModel? schedule = scheduleByUid[uid];
      if (schedule == null || !_hasScheduleInput(schedule)) {
        return <String>[];
      }
    }

    Set<String>? common;

    for (final String uid in participantUids) {
      final ScheduleModel schedule = scheduleByUid[uid]!;
      final Set<String> userSlots = <String>{};

      schedule.timeSelection.forEach(
        (String date, List<String> times) {
          for (final String time in times) {
            userSlots.add('$date|$time');
          }
        },
      );

      common = common == null
          ? userSlots
          : common.intersection(userSlots);
    }

    final List<String> result = (common ?? <String>{})
        .map((slot) => slot.replaceFirst('|', ' '))
        .toList()
      ..sort();

    return result;
  }

  static String _formatDateTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}.$month.$day $hour:$minute';
  }

  static String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;

  const _SectionCard({
    this.title,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: const Color(0xFF8AA4FF),
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                ],
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white60),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(width: 11),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFAFC0FF),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool isCreator;
  final bool hasSchedule;

  const _ParticipantRow({
    required this.name,
    required this.isMe,
    required this.isCreator,
    required this.hasSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor:
              const Color(0xFF4A6CF7).withOpacity(0.18),
          child: Text(
            name.trim().isEmpty ? '?' : name.trim()[0],
            style: const TextStyle(
              color: Color(0xFFAFC0FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isMe)
                const _SmallBadge(
                  label: '나',
                  color: Color(0xFF4A6CF7),
                ),
              if (isCreator)
                const _SmallBadge(
                  label: '모임장',
                  color: Color(0xFFFFB020),
                ),
            ],
          ),
        ),
        Icon(
          hasSchedule
              ? Icons.check_circle_rounded
              : Icons.pending_outlined,
          color: hasSchedule
              ? const Color(0xFF4CD964)
              : Colors.white30,
          size: 21,
        ),
        const SizedBox(width: 5),
        Text(
          hasSchedule ? '입력 완료' : '미입력',
          style: TextStyle(
            color: hasSchedule
                ? const Color(0xFF81E895)
                : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
      child: Material(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF4A6CF7).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF8AA4FF),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
      ),
    );
  }
}
