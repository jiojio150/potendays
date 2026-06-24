import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  schedule,
  settlement,
  reminder,
  general,
}

class AppNotificationModel {
  final String documentPath;
  final String title;
  final String message;
  final AppNotificationType type;
  final String meetingId;
  final String meetingTitle;
  final List<String> targetUids;
  final List<String> readBy;
  final DateTime? createdAt;

  const AppNotificationModel({
    required this.documentPath,
    required this.title,
    required this.message,
    required this.type,
    required this.meetingId,
    required this.meetingTitle,
    required this.targetUids,
    required this.readBy,
    this.createdAt,
  });

  bool isReadBy(String uid) => readBy.contains(uid);

  factory AppNotificationModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String rawType = data['type'] as String? ?? 'general';

    return AppNotificationModel(
      documentPath: document.reference.path,
      title: data['title'] as String? ?? '알림',
      message: data['message'] as String? ?? '',
      type: AppNotificationType.values.firstWhere(
        (value) => value.name == rawType,
        orElse: () => AppNotificationType.general,
      ),
      meetingId: data['meetingId'] as String? ?? '',
      meetingTitle: data['meetingTitle'] as String? ?? '',
      targetUids: List<String>.from(data['targetUids'] ?? <String>[]),
      readBy: List<String>.from(data['readBy'] ?? <String>[]),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
