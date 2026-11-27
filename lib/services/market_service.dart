// Publishing buyer requests and seller ads, and updating ad prices.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/models/commodity.dart';
import 'package:feedtech/models/me.dart';
import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/services/notification_service.dart';
import 'package:feedtech/shared/utils/formatters.dart';

/// Publishes a buyer request and notifies every seller of that material. Returns (id, sellers notified).
Future<(String, int)> publishRequest(Json v) async {
  final c = Catalog.byId(v['materialId'] as String);
  final sellers = await db.collection('users').where('materials', arrayContains: c.id).get();
  final ref = db.collection('requests').doc();
  final b = db.batch()
    ..set(ref, {
      'buyerId': myUid,
      'company': Me.company,
      'area': v['area'],
      'materialId': c.id,
      'qty': v['qty'],
      'specs': v['specs'],
      'budget': v['budget'],
      'deliveryDate': Timestamp.fromMillisecondsSinceEpoch(v['date'] as int),
      'payment': v['payment'],
      'notes': ((v['notes'] ?? '') as String).trim(),
      'open': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  var notified = 0;
  for (final s in sellers.docs) {
    if (s.id == myUid || s.data()['role'] == 'buy') continue;
    addNotification(b,
        to: s.id,
        type: 'request',
        text: '${Me.company} محتاج ${tons(v['qty'] as int)} ${c.name} — قدّم عرضك',
        kind: 'request',
        target: ref.id);
    notified++;
  }
  await b.commit();
  return (ref.id, notified);
}

/// Publishes a seller ad, records its first price and adds the material to the seller's list.
Future<String> publishAd(Json v) async {
  final ref = db.collection('ads').doc();
  await (db.batch()
        ..set(ref, {
          'sellerId': myUid,
          'company': Me.company,
          'area': v['area'],
          'materialId': v['materialId'],
          'specs': v['specs'],
          'qty': v['qty'],
          'minOrder': v['minOrder'],
          'price': v['price'],
          'payments': v['payments'],
          'delivers': v['delivers'],
          'deliveryDays': v['delivers'] == true ? v['deliveryDays'] : 0,
          'photos': v['photos'],
          'notes': ((v['notes'] ?? '') as String).trim(),
          'active': true,
          'priceAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(db.collection('priceHistory').doc(), {
          'adId': ref.id,
          'sellerId': myUid,
          'materialId': v['materialId'],
          'price': v['price'],
          'qty': v['qty'],
          'at': FieldValue.serverTimestamp(),
        })
        ..update(db.doc('users/$myUid'), {
          'materials': FieldValue.arrayUnion([v['materialId']])
        }))
      .commit();
  return ref.id;
}

/// Updates (or just confirms) an ad's price; every update is kept in priceHistory.
Future<void> updateAdPrice(Doc ad, int price, int qty) async {
  final a = ad.data()!;
  await (db.batch()
        ..update(ad.reference, {'price': price, 'qty': qty, 'priceAt': FieldValue.serverTimestamp()})
        ..set(db.collection('priceHistory').doc(), {
          'adId': ad.id,
          'sellerId': myUid,
          'materialId': a['materialId'],
          'price': price,
          'qty': qty,
          'at': FieldValue.serverTimestamp(),
        }))
      .commit();
}
