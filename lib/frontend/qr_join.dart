import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/meeting_service.dart';

// REQ-F-14 QR을 통한 모임 참여 입력
// 스캔 결과를 홈 화면으로 반환하고 실제 참여 처리는 MeetingService에서 수행한다.
class QrJoinScreen extends StatefulWidget {
  const QrJoinScreen({super.key});

  @override
  State<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends State<QrJoinScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;

    final String? rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final String meetingId =
        MeetingService.extractMeetingId(rawValue);

    if (meetingId.isEmpty) return;

    _handled = true;
    Navigator.pop(context, rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '초대 QR 스캔',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          const _ScannerOverlay(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.68),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Poten Day 초대 QR을 사각형 안에 맞춰 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 245,
        height: 245,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF8AA4FF),
            width: 4,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
