import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/meeting_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();

  final MeetingService _meetingService = MeetingService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _participantController = TextEditingController();
  final _emojiController = TextEditingController(text: "🎉");

  int _inviteMethod = 0;

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _participantController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _showEmojiPicker() {
    final List<String> emojis = ['🎉', '🍕', '☕', '🍺', '⚽', '📚', '🎬', '🏠', '✈️', '🎂', '🔥', '📍'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('아이콘 선택', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: emojis.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() => _emojiController.text = emojis[index]);
                  Navigator.pop(context);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onCreateMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      await _meetingService.createMeeting(
        title: _titleController.text.trim(),
        emoji: _emojiController.text.isEmpty ? "🎉" : _emojiController.text,
        creatorUid: user.uid,
        participants: [user.uid],
        description: _descriptionController.text.trim(),
        participantLimit: int.tryParse(_participantController.text.trim()),
      );

      if (mounted) {
        _showSuccessDialog(); 
      }
    } catch (e) {
      debugPrint("생성 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모임 생성에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('모임 생성 완료! 🎉', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text('"${_titleController.text}" 모임이 생성되었습니다.', style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('확인', style: TextStyle(color: Color(0xFF4A6CF7))),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      _buildLabel('모임명', isRequired: true),
                      const SizedBox(height: 8),
                      _buildTitleField(),

                      const SizedBox(height: 20),

                      _buildLabel('모임 설명'),
                      const SizedBox(height: 8),
                      _buildDescriptionField(),

                      const SizedBox(height: 20),

                      _buildLabel('예상 참여 인원'),
                      const SizedBox(height: 8),
                      _buildParticipantField(),

                      const SizedBox(height: 20),

                      _buildLabel('초대 방식'),
                      const SizedBox(height: 8),
                      _buildInviteMethodToggle(),

                      const SizedBox(height: 36),

                      _buildCreateButton(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 상단 헤더
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Text(
            '모임 생성',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 라벨 위젯
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFFF453A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 모임명 및 이모지 입력 필드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTitleField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showEmojiPicker,
          child: SizedBox(
            width: 80,
            child: AbsorbPointer(
              child: TextFormField(
                controller: _emojiController,
                textAlign: TextAlign.center,
                readOnly: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: _inputDecoration(hintText: '🎉').copyWith(
                  labelText: "아이콘",
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(hintText: '종강 파티').copyWith(
              labelText: "모임명",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '모임명을 입력해주세요';
              }
              if (value.trim().length < 2) {
                return '모임명은 2자 이상 입력해주세요';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 모임 설명 입력 필드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      maxLines: 4,
      decoration: _inputDecoration(hintText: '2학기 종강을 기념해서...'),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 예상 참여 인원 입력 필드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildParticipantField() {
    return TextFormField(
      controller: _participantController,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(hintText: '5명'),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final count = int.tryParse(value);
          if (count == null || count < 1) {
            return '1명 이상 입력해주세요';
          }
          if (count > 100) {
            return '최대 100명까지 입력 가능합니다';
          }
        }
        return null;
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 초대 방식 토글
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildInviteMethodToggle() {
    return Row(
      children: [
        _InviteToggleButton(
          label: '링크 공유',
          icon: Icons.link_rounded,
          isSelected: _inviteMethod == 0,
          onTap: () => setState(() => _inviteMethod = 0),
        ),
        const SizedBox(width: 12),
        _InviteToggleButton(
          label: 'QR 코드',
          icon: Icons.qr_code_rounded,
          isSelected: _inviteMethod == 1,
          onTap: () => setState(() => _inviteMethod = 1),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 모임 생성하기 버튼
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onCreateMeeting,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A6CF7),
          disabledBackgroundColor: const Color(0xFF4A6CF7).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Text(
          '모임 생성하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 공통 InputDecoration
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
      filled: true,
      fillColor: const Color(0xFF2C2C2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A3A3C), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF453A), fontSize: 12),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 초대 방식 토글 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _InviteToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _InviteToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A6CF7).withOpacity(0.15)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A6CF7)
                : const Color(0xFF3A3A3C),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF4A6CF7) : Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF4A6CF7) : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}