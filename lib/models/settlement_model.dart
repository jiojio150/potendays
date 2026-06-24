import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final int totalAmount;
  final int perPersonAmount;
  final List<String> participantUids;
  final Map<String, int> memberAmounts;
  final String createdByUid;
  final DateTime? updatedAt;

  const SettlementModel({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.participantUids,
    required this.memberAmounts,
    required this.createdByUid,
    this.updatedAt,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> rawAmounts =
        Map<String, dynamic>.from(map['memberAmounts'] ?? <String, dynamic>{});

    return SettlementModel(
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      perPersonAmount: (map['perPersonAmount'] as num?)?.toInt() ?? 0,
      participantUids:
          List<String>.from(map['participantUids'] ?? <String>[]),
      memberAmounts: rawAmounts.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      createdByUid: map['createdByUid'] as String? ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAmount': totalAmount,
      'perPersonAmount': perPersonAmount,
      'participantUids': participantUids,
      'memberAmounts': memberAmounts,
      'createdByUid': createdByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
