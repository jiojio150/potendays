// lib/frontend/settlement.dart

import 'package:flutter/material.dart';

// 정산 입력 / 1/N 계산 — REQ-F-08
class SettlementScreen extends StatefulWidget {
  final String meetingTitle;
  final String meetingEmoji;
  final int participantCount;

  const SettlementScreen({
    super.key,
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
    this.participantCount = 5,
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late int _participantCount;
  final TextEditingController _amountController = TextEditingController(text: '82000');

  final List<String> _members = ['나', '김민수', '이지은', '박서윤', '최현우', '정하늘', '한지민', '오유진'];

  @override
  void initState() {
    super.initState();
    _participantCount = widget.participantCount;
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _totalAmount {
    final onlyNumber = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(onlyNumber) ?? 0;
  }

  int get _perPersonAmount {
    if (_participantCount <= 0) return 0;
    return _totalAmount ~/ _participantCount;
  }

  void _increaseParticipant() {
    setState(() => _participantCount++);
  }

  void _decreaseParticipant() {
    if (_participantCount <= 1) return;
    setState(() => _participantCount--);
  }

  @override
  Widget build(BuildContext context) {
    final displayMembers = List.generate(_participantCount, (index) {
      if (index < _members.length) {
        return _members[index];
      }
      return '참여자 ${index + 1}';
    });

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
                      '참여 인원',
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
                      '참여자별 정산',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...displayMembers.map(
                          (name) => _MemberSettlementRow(
                        name: name,
                        amount: _perPersonAmount,
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
            onPressed: () => Navigator.pop(context),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
    return Row(
      children: [
        _RoundButton(icon: Icons.remove, onTap: _decreaseParticipant),
        const SizedBox(width: 18),
        Text(
          '$_participantCount명',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 18),
        _RoundButton(icon: Icons.add, onTap: _increaseParticipant),
      ],
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
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _MemberSettlementRow extends StatelessWidget {
  final String name;
  final int amount;

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  const _MemberSettlementRow({required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Text(
            '${_formatMoney(amount)}원',
            style: const TextStyle(
              color: Color(0xFF9FC2FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
