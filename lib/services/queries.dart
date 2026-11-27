// Firestore queries and small helpers for reading deals.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/services/firebase_service.dart';

Query<Json> get activeAds => db.collection('ads').where('active', isEqualTo: true);
Query<Json> get myAdsQuery => db.collection('ads').where('sellerId', isEqualTo: myUid);
Query<Json> get openRequests => db.collection('requests').where('open', isEqualTo: true);
Query<Json> get myRequestsQuery => db.collection('requests').where('buyerId', isEqualTo: myUid);
Query<Json> get myNegotiations => db.collection('negotiations').where('parties', arrayContains: myUid);
Query<Json> get myOrders => db.collection('orders').where('parties', arrayContains: myUid);
Query<Json> get myNotifications => db.collection('notifications').where('to', isEqualTo: myUid);

/// Newest first by a timestamp field (pending server times count as now).
List<QDoc> newest(Iterable<QDoc> docs, [String field = 'createdAt']) =>
    docs.toList()..sort((a, b) => timeOf(b.data()[field]).compareTo(timeOf(a.data()[field])));

bool myTurn(Json n) => n['status'] == 'negotiating' && n['lastBy'] != myUid;
String otherCompany(Json d) => d['buyerId'] == myUid ? d['sellerCompany'] as String : d['buyerCompany'] as String;
String otherId(Json d) => (d['buyerId'] == myUid ? d['sellerId'] : d['buyerId']) as String;
