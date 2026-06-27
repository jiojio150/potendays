import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/meeting_service.dart';

// REQ-F-14 모임 초대 링크 및 QR 공유
class InviteShareScreen extends StatelessWidget {
  final String meetingId;
  final String meetingTitle;
  final String meetingEmoji;
  final String preferredInviteMethod;

  const InviteShareScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    this.preferredInviteMethod = 'link',
    this.meetingEmoji = '📅',
  });

  String get _inviteLink => MeetingService.createInviteLink(meetingId);

  String get _shareText {
    return '$meetingEmoji $meetingTitle 모임에 초대합니다!\n\n'
        'Poten Day 앱에서 아래 링크를 붙여넣거나 QR을 스캔해 주세요.\n'
        '$_inviteLink\n\n'
        '초대 코드: $meetingId';
  }

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: _shareText, subject: '$meetingTitle 모임 초대'),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유에 실패했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool prefersQr = preferredInviteMethod == 'qr';

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: const Text(
          '모임 초대',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$meetingEmoji $meetingTitle',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 QR 또는 초대 링크를 참여자에게 공유하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _InviteMethodNotice(prefersQr: prefersQr),
            const SizedBox(height: 26),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: _inviteLink,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 26),
            _InfoBox(
              label: '초대 코드',
              value: meetingId,
              onCopy: () => _copy(context, meetingId, '초대 코드가 복사되었습니다.'),
            ),
            const SizedBox(height: 12),
            _InfoBox(
              label: '초대 링크',
              value: _inviteLink,
              onCopy: () => _copy(context, _inviteLink, '초대 링크가 복사되었습니다.'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _share(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                ),
                icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                label: Text(
                  prefersQr ? 'QR 코드 공유' : '초대 링크 공유',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '현재 버전에서는 공유받은 링크를 Poten Day 앱의 '
              '‘모임 참여하기’ 입력창에 붙여넣거나 QR 스캔으로 참여합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteMethodNotice extends StatelessWidget {
  final bool prefersQr;

  const _InviteMethodNotice({required this.prefersQr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF28345F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4A6CF7)),
      ),
      child: Row(
        children: [
          Icon(
            prefersQr ? Icons.qr_code_2_rounded : Icons.link_rounded,
            color: const Color(0xFF9FC2FF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prefersQr ? '선택한 초대 방식: QR 코드' : '선택한 초대 방식: 링크 공유',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _InfoBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF8AA4FF)),
          ),
        ],
      ),
    );
  }
}
