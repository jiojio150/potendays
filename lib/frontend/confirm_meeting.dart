import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/meeting_service.dart';

// 모임 날짜·시간·장소 확정 화면
class ConfirmMeetingScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final String meetingEmoji;

  const ConfirmMeetingScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    this.meetingEmoji = '📅',
  });

  @override
  State<ConfirmMeetingScreen> createState() => _ConfirmMeetingScreenState();
}

class _ConfirmMeetingScreenState extends State<ConfirmMeetingScreen> {
  final MeetingService _meetingService = MeetingService();
  final TextEditingController _placeNameController = TextEditingController();
  final TextEditingController _placeAddressController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCreator = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMeeting();
  }

  @override
  void dispose() {
    _placeNameController.dispose();
    _placeAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadMeeting() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _meetingService.getMeeting(widget.meetingId);

      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('모임 정보를 찾을 수 없습니다.');
      }

      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
      final Timestamp? confirmedTimestamp =
          data['confirmedDateTime'] as Timestamp?;

      final DateTime? confirmedDateTime = confirmedTimestamp?.toDate();

      if (!mounted) return;

      setState(() {
        _isCreator = currentUid != null &&
            currentUid == (data['creatorUid'] as String? ?? '');

        if (confirmedDateTime != null) {
          _selectedDate = DateTime(
            confirmedDateTime.year,
            confirmedDateTime.month,
            confirmedDateTime.day,
          );
          _selectedTime = TimeOfDay.fromDateTime(confirmedDateTime);
        }

        _placeNameController.text =
            data['confirmedPlaceName'] as String? ?? '';
        _placeAddressController.text =
            data['confirmedPlaceAddress'] as String? ?? '';

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '모임 정보를 불러오지 못했습니다.\n$error';
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A6CF7),
              surface: Color(0xFF2C2C2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A6CF7),
              surface: Color(0xFF2C2C2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_isCreator) {
      _showMessage('모임장만 일정과 장소를 확정할 수 있습니다.');
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('날짜와 시간을 모두 선택해 주세요.');
      return;
    }

    final String placeName = _placeNameController.text.trim();
    if (placeName.isEmpty) {
      _showMessage('장소명을 입력해 주세요.');
      return;
    }

    final DateTime confirmedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _isSaving = true);

    try {
      await _meetingService.confirmMeeting(
        meetingId: widget.meetingId,
        confirmedDateTime: confirmedDateTime,
        placeName: placeName,
        placeAddress: _placeAddressController.text,
      );

      if (!mounted) return;

      _showMessage('모임 날짜와 장소를 확정했습니다.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('확정 저장 실패: $error');
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
          '모임 일정 확정',
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
            '${widget.meetingEmoji} ${widget.meetingTitle}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCreator
                ? '모임의 최종 날짜, 시간, 장소를 선택해 주세요.'
                : '확정된 모임 정보를 확인할 수 있습니다.',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 26),
          const _SectionTitle('날짜 및 시간'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SelectionCard(
                  icon: Icons.calendar_month_rounded,
                  label: _selectedDate == null
                      ? '날짜 선택'
                      : _formatDate(_selectedDate!),
                  onTap: _isCreator ? _pickDate : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SelectionCard(
                  icon: Icons.access_time_rounded,
                  label: _selectedTime == null
                      ? '시간 선택'
                      : _selectedTime!.format(context),
                  onTap: _isCreator ? _pickTime : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SectionTitle('장소'),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _placeNameController,
            label: '장소명',
            hint: '예: 인하대학교 정석학술정보관',
            icon: Icons.place_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _placeAddressController,
            label: '주소 또는 상세 위치',
            hint: '예: 인천 미추홀구 인하로 100',
            icon: Icons.map_rounded,
          ),
          if (!_isCreator) ...[
            const SizedBox(height: 20),
            const Text(
              '모임장만 확정 정보를 수정할 수 있습니다.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 30),
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
                  _isSaving ? '저장 중...' : '날짜·장소 확정',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: _isCreator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIconColor: const Color(0xFF8AA4FF),
        filled: true,
        fillColor: const Color(0xFF242426),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SelectionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF242426),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8AA4FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap == null ? Colors.white60 : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
