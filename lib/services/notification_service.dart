// In-app notifications (the `notifications` collection).

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/services/firebase_service.dart';

void addNotification(WriteBatch b,
    {required String to, required String type, required String text, required String kind, required String target}) {
  b.set(db.collection('notifications').doc(), {
    'to': to,
    'from': myUid,
    'type': type,
    'text': text,
    'kind': kind,
    'target': target,
    'read': false,
    'at': FieldValue.serverTimestamp(),
  });
}
