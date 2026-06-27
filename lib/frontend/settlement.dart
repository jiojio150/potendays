// lib/frontend/settlement.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/local_notification_service.dart';

// 정산 입력 / 1/N 계산 — REQ-F-08
class SettlementScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final String meetingEmoji;
  final int participantCount;

  const SettlementScreen({
    super.key,
    this.meetingId = '',
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
    this.participantCount = 5,
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late int _participantCount;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  // 모임 전체 참여자 UID
  List<String> _participantUids = [];

  // 실제 정산에 참여하는 사용자 UID
  List<String> _selectedParticipantUids = [];

  // UID별 실제 사용자 이름
  Map<String, String> _participantNames = {};

  final TextEditingController _amountController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();

    debugPrint('정산 화면 meetingId: ${widget.meetingId}');

    _participantCount = widget.participantCount;
    _amountController.addListener(_handleAmountChanged);

    _loadParticipants();
  }

  void _handleAmountChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // Firestore에서 현재 모임의 실제 참여자 UID 목록 불러오기
  Future<void> _loadParticipants() async {
    if (widget.meetingId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = '모임 ID가 없습니다.';
      });

      return;
    }

    try {
      final meetingDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meetingId)
          .get();

      if (!meetingDoc.exists) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _loadError = '모임 정보를 찾을 수 없습니다.';
        });

        return;
      }

      final data = meetingDoc.data();

      final participants = List<String>.from(data?['participants'] ?? []);

      debugPrint('불러온 참여자 UID: $participants');

      final participantNames = await _loadParticipantNames(participants);

      debugPrint('불러온 참여자 이름: $participantNames');

      if (!mounted) return;

      setState(() {
        _participantUids = participants;
        _selectedParticipantUids = List<String>.from(participants);
        _participantNames = participantNames;

        _participantCount = _selectedParticipantUids.length;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('참여자 불러오기 오류: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = '참여자 정보를 불러오지 못했습니다.\n$e';
      });
    }
  }

  // users/{uid} 문서에서 실제 사용자 이름 불러오기
  Future<Map<String, String>> _loadParticipantNames(
    List<String> participantUids,
  ) async {
    final Map<String, String> names = {};

    for (final uid in participantUids) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();

          final displayName = data?['displayName']?.toString().trim() ?? '';

          names[uid] = displayName.isNotEmpty ? displayName : _formatUid(uid);
        } else {
          names[uid] = _formatUid(uid);
        }
      } catch (e) {
        debugPrint('사용자 이름 조회 오류 ($uid): $e');
        names[uid] = _formatUid(uid);
      }
    }

    return names;
  }

  // 참여자를 정산에 포함하거나 제외
  void _toggleParticipant(String uid) {
    setState(() {
      if (_selectedParticipantUids.contains(uid)) {
        if (_selectedParticipantUids.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('정산 참여자는 최소 1명이어야 합니다.')),
          );

          return;
        }

        _selectedParticipantUids.remove(uid);
      } else {
        _selectedParticipantUids.add(uid);
      }

      _participantCount = _selectedParticipantUids.length;
    });
  }

  // 정산 정보와 정산 요청 알림을 Firestore에 동시에 저장
  Future<void> _saveSettlement() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보가 없습니다.')));
      return;
    }

    if (widget.meetingId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모임 정보가 없습니다.')));
      return;
    }

    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('총 지출 금액을 입력해주세요.')));
      return;
    }

    if (_selectedParticipantUids.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('정산 참여자를 선택해주세요.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final meetingRef = firestore.collection('meetings').doc(widget.meetingId);

      final settlementRef = meetingRef.collection('settlements').doc();

      final notificationRef = meetingRef.collection('notifications').doc();

      final batch = firestore.batch();

      batch.set(settlementRef, {
        'meetingId': widget.meetingId,
        'meetingTitle': widget.meetingTitle,
        'meetingEmoji': widget.meetingEmoji,
        'totalAmount': _totalAmount,
        'perPersonAmount': _perPersonAmount,
        'participantUids': List<String>.from(_selectedParticipantUids),
        'participantCount': _selectedParticipantUids.length,
        'createdByUid': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'paidUids': <String>[],
      });

      batch.set(notificationRef, {
        'meetingId': widget.meetingId,
        'meetingTitle': widget.meetingTitle,
        'meetingEmoji': widget.meetingEmoji,
        'settlementId': settlementRef.id,
        'type': 'settlement',
        'title': '💸 정산 요청',
        'message':
            '${widget.meetingTitle} 정산이 등록되었습니다. '
            '1인당 ${_formatMoney(_perPersonAmount)}원입니다.',
        'targetUids': List<String>.from(_selectedParticipantUids),
        'createdByUid': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String>[],
      });

      // 로컬 알림 서비스에서 정산 리마인드를 다시 예약하지 않도록
      // 모임 문서의 정산 상태도 함께 갱신한다.
      batch.update(meetingRef, {
        'settlementCompleted': true,
        'settledAt': FieldValue.serverTimestamp(),
        'settlementUpdatedByUid': currentUser.uid,
        'settlementReminderAt': FieldValue.delete(),
        'settlementReminderSent': false,
        'settlementReminderSentAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 현재 기기의 예약 알림을 최신 Firestore 상태에 맞게 다시 동기화한다.
      await LocalNotificationService.instance.syncCurrentUserMeetings();

      debugPrint('정산 저장 성공: ${settlementRef.id}');
      debugPrint('알림 저장 성공: ${notificationRef.id}');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('정산과 알림이 저장되었습니다.')));

      Navigator.pop(context);
    } catch (e) {
      debugPrint('정산 및 알림 저장 오류: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('정산 저장에 실패했습니다.\n$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  int get _totalAmount {
    final onlyNumber = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');

    return int.tryParse(onlyNumber) ?? 0;
  }

  int get _perPersonAmount {
    if (_selectedParticipantUids.isEmpty) {
      return 0;
    }

    return _totalAmount ~/ _selectedParticipantUids.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1C1C1E),
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      '총 지출 금액',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 8),

                    _buildAmountField(),

                    const SizedBox(height: 22),

                    const Text(
                      '정산 참여 인원',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 10),

                    _buildParticipantCounter(),

                    const SizedBox(height: 24),

                    _buildPerPersonCard(),

                    const SizedBox(height: 24),

                    const Divider(color: Color(0xFF3A3A3C)),

                    const SizedBox(height: 18),

                    const Text(
                      '정산 참여자 선택',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      '정산에 포함할 참여자를 선택하세요.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),

                    const SizedBox(height: 12),

                    if (_participantUids.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '참여자가 없습니다.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._participantUids.map((uid) {
                        final isSelected = _selectedParticipantUids.contains(
                          uid,
                        );

                        return _ParticipantSettlementRow(
                          name: _participantNames[uid] ?? _formatUid(uid),
                          amount: _perPersonAmount,
                          isSelected: isSelected,
                          onChanged: () {
                            _toggleParticipant(uid);
                          },
                        );
                      }),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettlement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A6CF7),
                          disabledBackgroundColor: const Color(0x804A6CF7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '정산 확정',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
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
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Text(
            '정산하기',
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

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        suffixText: '원',
        suffixStyle: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: const Color(0xFF242424),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A6CF7), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildParticipantCounter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Text(
            '정산 참여 $_participantCount명',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '전체 ${_participantUids.length}명',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPerPersonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF294C7A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            '1인당 금액',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatMoney(_perPersonAmount)}원',
            style: const TextStyle(
              color: Color(0xFF9FC2FF),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static String _formatUid(String uid) {
    if (uid.length > 8) {
      return '${uid.substring(0, 8)}...';
    }

    return uid;
  }
}

class _ParticipantSettlementRow extends StatelessWidget {
  final String name;
  final int amount;
  final bool isSelected;
  final VoidCallback onChanged;

  const _ParticipantSettlementRow({
    required this.name,
    required this.amount,
    required this.isSelected,
    required this.onChanged,
  });

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.7),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) {
                onChanged();
              },
              activeColor: const Color(0xFF4A6CF7),
              checkColor: Colors.white,
            ),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              isSelected ? '${_formatMoney(amount)}원' : '정산 제외',
              style: TextStyle(
                color: isSelected ? const Color(0xFF9FC2FF) : Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
