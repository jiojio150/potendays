import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification_model.dart';

// REQ-F-09 앱 내부 알림 내역 조회 및 읽음 처리
class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<AppNotificationModel>> watchMyNotifications() {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      return Stream<List<AppNotificationModel>>.value(
        <AppNotificationModel>[],
      );
    }

    return _db
        .collectionGroup('notifications')
        .where('targetUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final List<AppNotificationModel> result = snapshot.docs
          .map(AppNotificationModel.fromDocument)
          .toList();

      result.sort((a, b) {
        final DateTime aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return result;
    });
  }

  Future<void> markAsRead(AppNotificationModel notification) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || notification.isReadBy(uid)) return;

    await _db.doc(notification.documentPath).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}
