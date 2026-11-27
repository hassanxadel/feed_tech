// Negotiations and orders: every write keeps the full history.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/domain/deal_rules.dart';
import 'package:feedtech/models/commodity.dart';
import 'package:feedtech/models/me.dart';
import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/services/notification_service.dart';
import 'package:feedtech/services/queries.dart';
import 'package:feedtech/shared/utils/formatters.dart';

/// Opens a negotiation with its first offer (a seller quoting a request, or a buyer offering on an ad).
Future<String> startNegotiation({
  required String buyerId,
  required String sellerId,
  required String buyerCompany,
  required String sellerCompany,
  required String materialId,
  required Map specs,
  required int price,
  required int qty,
  required int dateMs,
  required String payment,
  required String place,
  String note = '',
  String? requestId,
  String? adId,
}) async {
  final ref = db.collection('negotiations').doc();
  final c = Catalog.byId(materialId);
  final b = db.batch()
    ..set(ref, {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'parties': [buyerId, sellerId],
      'buyerCompany': buyerCompany,
      'sellerCompany': sellerCompany,
      'materialId': materialId,
      'specs': specs,
      'price': price,
      'qty': qty,
      'deliveryDate': Timestamp.fromMillisecondsSinceEpoch(dateMs),
      'payment': payment,
      'place': place,
      'note': note.trim(),
      if (requestId != null) 'requestId': requestId,
      if (adId != null) 'adId': adId,
      'status': 'negotiating',
      'lastBy': myUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    })
    ..set(ref.collection('steps').doc(), {
      'by': myUid,
      'kind': 'offer',
      'price': price,
      'qty': qty,
      'note': note.trim(),
      'at': FieldValue.serverTimestamp(),
    });
  addNotification(b,
      to: myUid == buyerId ? sellerId : buyerId,
      type: 'offer',
      text: '${Me.company} بعتلك عرض: ${tons(qty)} ${c.name} بـ ${perTon(price)}',
      kind: 'negotiation',
      target: ref.id);
  await b.commit();
  return ref.id;
}

/// Accept, decline, cancel or counter. Every step is added to the history; nothing is overwritten.
Future<void> negotiate(Doc n, DealAction action, {int? price, int? qty}) async {
  final d = n.data()!;
  final status = nextStatus(DealStatus.values.byName(d['status'] as String), action,
      actorMadeLastOffer: d['lastBy'] == myUid)!;
  final c = Catalog.byId(d['materialId'] as String);
  final p = price ?? (d['price'] as num).toInt();
  final q = qty ?? (d['qty'] as num).toInt();
  final b = db.batch()
    ..update(n.reference, {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (action == DealAction.counter) ...{'price': p, 'qty': q, 'lastBy': myUid},
    })
    ..set(n.reference.collection('steps').doc(),
        {'by': myUid, 'kind': action.name, 'price': p, 'qty': q, 'at': FieldValue.serverTimestamp()});
  addNotification(b,
      to: otherId(d),
      type: action.name,
      text: switch (action) {
        DealAction.counter => '${Me.company} رد بسعر جديد: ${perTon(p)} على ${c.name}',
        DealAction.accept => '${Me.company} وافق على ${perTon(p)} — ${c.name}. كمّلوا الطلبية',
        DealAction.decline => '${Me.company} رفض العرض على ${c.name}',
        DealAction.cancel => '${Me.company} لغى التفاوض على ${c.name}',
      },
      kind: 'negotiation',
      target: n.id);
  await b.commit();
}

/// The buyer turns an agreed negotiation into an order. Returns the order id.
Future<String> createOrder(Doc n, {required String payment, required int dateMs, required String place}) async {
  final d = n.data()!;
  final ref = db.collection('orders').doc();
  final qty = (d['qty'] as num).toInt(), price = (d['price'] as num).toInt();
  final b = db.batch()
    ..set(ref, {
      'negotiationId': n.id,
      'buyerId': d['buyerId'],
      'sellerId': d['sellerId'],
      'parties': [d['buyerId'], d['sellerId']],
      'buyerCompany': d['buyerCompany'],
      'sellerCompany': d['sellerCompany'],
      'materialId': d['materialId'],
      'specs': d['specs'],
      'qty': qty,
      'price': price,
      'total': qty * price,
      'payment': payment,
      'deliveryDate': Timestamp.fromMillisecondsSinceEpoch(dateMs),
      'place': place,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    })
    ..update(n.reference, {'orderId': ref.id, 'updatedAt': FieldValue.serverTimestamp()})
    // Each side's phone is shown to the other only after the seller confirms (see firestore.rules).
    ..set(ref.collection('contacts').doc(myUid), {'phone': Me.phone});
  addNotification(b,
      to: d['sellerId'] as String,
      type: 'order',
      text: 'طلبية جديدة من ${Me.company}: ${tons(qty)} ${Catalog.byId(d['materialId'] as String).name} — أكّدها',
      kind: 'order',
      target: ref.id);
  await b.commit();
  return ref.id;
}

Future<void> moveOrder(Doc o, String to) async {
  final d = o.data()!;
  final b = db.batch()..update(o.reference, {'status': to, 'updatedAt': FieldValue.serverTimestamp()});
  if (to == 'confirmed') b.set(o.reference.collection('contacts').doc(myUid), {'phone': Me.phone});
  addNotification(b,
      to: otherId(d),
      type: 'order-$to',
      text: switch (to) {
        'confirmed' => '${Me.company} أكّد الطلبية — رقم تليفونه ظهر عندك',
        'delivered' => '${Me.company} سجّل إن البضاعة اتسلمت',
        _ => '${Me.company} لغى الطلبية',
      },
      kind: 'order',
      target: o.id);
  await b.commit();
}
