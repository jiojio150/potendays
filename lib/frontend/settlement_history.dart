// lib/frontend/settlement_history.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettlementHistoryScreen extends StatelessWidget {
  final String meetingId;
  final String meetingTitle;
  final String meetingEmoji;
  final String initialSettlementId;

  const SettlementHistoryScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingEmoji,
    this.initialSettlementId = '',
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('meetings')
                    .doc(meetingId)
                    .collection('settlements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildError(snapshot.error);
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final settlementDocs = snapshot.data?.docs ?? [];

                  if (settlementDocs.isEmpty) {
                    return _buildEmpty();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    itemCount: settlementDocs.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 14);
                    },
                    itemBuilder: (context, index) {
                      final settlementDoc = settlementDocs[index];

                      return _SettlementHistoryCard(
                        meetingId: meetingId,
                        settlementId: settlementDoc.id,
                        data: settlementDoc.data(),
                        isHighlighted: settlementDoc.id == initialSettlementId,
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정산 내역',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$meetingEmoji $meetingTitle',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 58),
            SizedBox(height: 16),
            Text(
              '아직 등록된 정산 내역이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '정산하기 화면에서 정산을 확정하면\n여기에 내역이 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '정산 내역을 불러오지 못했습니다.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SettlementHistoryCard extends StatefulWidget {
  final String meetingId;
  final String settlementId;
  final Map<String, dynamic> data;
  final bool isHighlighted;

  const _SettlementHistoryCard({
    required this.meetingId,
    required this.settlementId,
    required this.data,
    this.isHighlighted = false,
  });

  @override
  State<_SettlementHistoryCard> createState() => _SettlementHistoryCardState();
}

class _SettlementHistoryCardState extends State<_SettlementHistoryCard> {
  bool _isUpdating = false;

  int get _totalAmount {
    final value = widget.data['totalAmount'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  int get _perPersonAmount {
    final value = widget.data['perPersonAmount'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  List<String> get _participantUids {
    final value = widget.data['participantUids'];

    if (value is List) {
      return value.map((uid) => uid.toString()).toList();
    }

    return [];
  }

  List<String> get _paidUids {
    final value = widget.data['paidUids'];

    if (value is List) {
      return value.map((uid) => uid.toString()).toList();
    }

    return [];
  }

  int get _participantCount {
    final value = widget.data['participantCount'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return _participantUids.length;
  }

  int get _paidCount {
    return _paidUids.length;
  }

  String get _status {
    return widget.data['status']?.toString() ?? 'pending';
  }

  bool get _isCompleted {
    return _status == 'completed' ||
        (_participantCount > 0 && _paidCount >= _participantCount);
  }

  bool get _isCurrentUserParticipant {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return false;
    }

    return _participantUids.contains(uid);
  }

  bool get _hasCurrentUserPaid {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return false;
    }

    return _paidUids.contains(uid);
  }

  Future<void> _togglePaymentStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    if (!_participantUids.contains(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 정산의 참여자만 납부 처리를 할 수 있습니다.')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final settlementRef = FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('settlements')
          .doc(widget.settlementId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(settlementRef);

        if (!snapshot.exists) {
          throw Exception('정산 문서를 찾을 수 없습니다.');
        }

        final data = snapshot.data() ?? {};

        final participantUids = List<String>.from(
          data['participantUids'] ?? [],
        );

        final paidUids = List<String>.from(data['paidUids'] ?? []);

        if (!participantUids.contains(currentUser.uid)) {
          throw Exception('정산 참여자가 아닙니다.');
        }

        if (paidUids.contains(currentUser.uid)) {
          paidUids.remove(currentUser.uid);
        } else {
          paidUids.add(currentUser.uid);
        }

        final bool isCompleted =
            participantUids.isNotEmpty &&
            paidUids.length >= participantUids.length;

        transaction.update(settlementRef, {
          'paidUids': paidUids,
          'status': isCompleted ? 'completed' : 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasCurrentUserPaid ? '납부 완료가 취소되었습니다.' : '납부 완료 처리되었습니다.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('납부 상태 변경 오류: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('납부 상태 변경에 실패했습니다.\n$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserPaid = _hasCurrentUserPaid;
    final currentUserParticipant = _isCurrentUserParticipant;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isHighlighted
              ? const Color(0xFF8AA4FF)
              : _isCompleted
              ? const Color(0xFF42C77A).withValues(alpha: 0.5)
              : Colors.white12,
          width: widget.isHighlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isHighlighted) ...[
            const Text(
              '알림에서 열린 정산',
              style: TextStyle(
                color: Color(0xFF9FC2FF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? const Color(0xFF214E35)
                      : const Color(0xFF294C7A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isCompleted ? Icons.check_rounded : Icons.payments_rounded,
                  color: _isCompleted
                      ? const Color(0xFF7FE3A6)
                      : const Color(0xFF9FC2FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDate(widget.data['createdAt']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StatusChip(isCompleted: _isCompleted),
            ],
          ),
          const SizedBox(height: 18),
          _InformationRow(
            label: '총 지출 금액',
            value: '${_formatMoney(_totalAmount)}원',
          ),
          const SizedBox(height: 10),
          _InformationRow(
            label: '1인당 금액',
            value: '${_formatMoney(_perPersonAmount)}원',
            valueColor: const Color(0xFF9FC2FF),
          ),
          const SizedBox(height: 10),
          _InformationRow(label: '정산 참여자', value: '$_participantCount명'),
          const SizedBox(height: 10),
          _InformationRow(
            label: '납부 완료',
            value: '$_paidCount / $_participantCount명',
            valueColor: _isCompleted ? const Color(0xFF7FE3A6) : Colors.white,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF3A3A3C), height: 1),
          const SizedBox(height: 14),

          if (currentUserParticipant)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _togglePaymentStatus,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        currentUserPaid
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  currentUserPaid ? '납부 완료 취소' : '납부 완료',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentUserPaid
                      ? const Color(0xFF5A5A5C)
                      : const Color(0xFF4A6CF7),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            const Text(
              '이 정산의 참여자가 아니므로 납부 처리를 할 수 없습니다.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),

          const SizedBox(height: 12),

          Text(
            '정산 ID: ${_shortId(widget.settlementId)}',
            style: const TextStyle(color: Colors.white30, fontSize: 12),
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

  static String _shortId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return '${id.substring(0, 8)}...';
  }

  static String _formatDate(dynamic value) {
    if (value is! Timestamp) {
      return '저장 시간 확인 중';
    }

    final date = value.toDate();

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year.$month.$day $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  final bool isCompleted;

  const _StatusChip({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF214E35) : const Color(0xFF4A3B1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? '정산 완료' : '정산 진행 중',
        style: TextStyle(
          color: isCompleted
              ? const Color(0xFF7FE3A6)
              : const Color(0xFFFFCC66),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InformationRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
