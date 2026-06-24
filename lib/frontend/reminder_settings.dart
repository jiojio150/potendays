import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/reminder_service.dart';

// REQ-F-09 자동 리마인드 설정 화면
class ReminderSettingsScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final String creatorUid;

  const ReminderSettingsScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.creatorUid,
  });

  @override
  State<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends State<ReminderSettingsScreen> {
  final ReminderService _reminderService = ReminderService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = true;
  int _scheduleMinutesBefore = 1440;
  int _settlementDelayHours = 24;
  int _inactiveDays = 30;

  DateTime? _nextScheduleReminderAt;
  DateTime? _settlementReminderAt;
  DateTime? _nextInactiveReminderAt;
  String? _errorMessage;

  bool get _isCreator =>
      FirebaseAuth.instance.currentUser?.uid == widget.creatorUid;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final ReminderSettingsData settings =
          await _reminderService.getSettings(widget.meetingId);

      if (!mounted) return;

      setState(() {
        _enabled = settings.enabled;
        _scheduleMinutesBefore =
            settings.scheduleMinutesBefore;
        _settlementDelayHours =
            settings.settlementDelayHours;
        _inactiveDays = settings.inactiveDays;
        _nextScheduleReminderAt =
            settings.nextScheduleReminderAt;
        _settlementReminderAt =
            settings.settlementReminderAt;
        _nextInactiveReminderAt =
            settings.nextInactiveReminderAt;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '리마인드 설정을 불러오지 못했습니다.\n$error';
      });
    }
  }

  Future<void> _save() async {
    if (!_isCreator) {
      _showMessage('모임장만 리마인드 설정을 변경할 수 있습니다.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _reminderService.saveSettings(
        meetingId: widget.meetingId,
        enabled: _enabled,
        scheduleMinutesBefore: _scheduleMinutesBefore,
        settlementDelayHours: _settlementDelayHours,
        inactiveDays: _inactiveDays,
      );

      if (!mounted) return;

      _showMessage('리마인드 설정을 저장했습니다.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('리마인드 설정 저장 실패: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: const Text(
          '리마인드 설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.meetingTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이 설정은 자동 알림을 실행할 시점 계산에 사용됩니다.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          _SettingCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF8AA4FF),
              title: const Text(
                '자동 리마인드 사용',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                '일정 임박, 정산 필요, 장기간 미모임 조건을 확인합니다.',
                style: TextStyle(color: Colors.white54),
              ),
              value: _enabled,
              onChanged: _isCreator
                  ? (value) => setState(() => _enabled = value)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown(
                  title: '일정 임박 알림',
                  value: _scheduleMinutesBefore,
                  items: const {
                    60: '1시간 전',
                    180: '3시간 전',
                    720: '12시간 전',
                    1440: '1일 전',
                    2880: '2일 전',
                  },
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _scheduleMinutesBefore = value);
                    }
                  },
                ),
                const Divider(color: Color(0xFF3A3A3C), height: 30),
                _buildDropdown(
                  title: '정산 필요 알림',
                  value: _settlementDelayHours,
                  items: const {
                    0: '모임 종료 시각부터',
                    3: '3시간 후',
                    12: '12시간 후',
                    24: '1일 후',
                    48: '2일 후',
                  },
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _settlementDelayHours = value);
                    }
                  },
                ),
                const Divider(color: Color(0xFF3A3A3C), height: 30),
                _buildDropdown(
                  title: '장기간 미모임 알림',
                  value: _inactiveDays,
                  items: const {
                    7: '7일 후',
                    14: '14일 후',
                    30: '30일 후',
                    60: '60일 후',
                    90: '90일 후',
                  },
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _inactiveDays = value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '현재 계산된 실행 예정 시각',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _DueRow(
                  label: '일정 임박',
                  value: _formatNullable(_nextScheduleReminderAt),
                ),
                const SizedBox(height: 10),
                _DueRow(
                  label: '정산 필요',
                  value: _formatNullable(_settlementReminderAt),
                ),
                const SizedBox(height: 10),
                _DueRow(
                  label: '장기간 미모임',
                  value: _formatNullable(_nextInactiveReminderAt),
                ),
              ],
            ),
          ),
          if (!_isCreator) ...[
            const SizedBox(height: 16),
            const Text(
              '참여자는 설정을 확인할 수만 있습니다.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 26),
          if (_isCreator)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                ),
                child: Text(
                  _isSaving ? '저장 중...' : '리마인드 설정 저장',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String title,
    required int value,
    required Map<int, String> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ),
        DropdownButton<int>(
          value: value,
          dropdownColor: const Color(0xFF2C2C2E),
          style: const TextStyle(
            color: Color(0xFFAFC0FF),
            fontWeight: FontWeight.bold,
          ),
          underline: const SizedBox.shrink(),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: _isCreator && _enabled ? onChanged : null,
        ),
      ],
    );
  }

  static String _formatNullable(DateTime? value) {
    if (value == null) return '일정 확정 후 계산';

    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}.$month.$day $hour:$minute';
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;

  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: child,
    );
  }
}

class _DueRow extends StatelessWidget {
  final String label;
  final String value;

  const _DueRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 95,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
