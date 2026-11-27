// Firestore access, the materials catalogue, Arabic formatting and every write the app makes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deal_rules.dart';
import 'logic.dart';

typedef Json = Map<String, dynamic>;
typedef Doc = DocumentSnapshot<Json>;
typedef QDoc = QueryDocumentSnapshot<Json>;

final db = FirebaseFirestore.instance;
String get myUid => FirebaseAuth.instance.currentUser!.uid;

/// The signed-in business's profile, kept current by the app shell.
class Me {
  static Json data = {};
  static String get company => (data['company'] ?? '') as String;
  static String get name => (data['name'] ?? '') as String;
  static String get area => (data['area'] ?? 'السادات') as String;
  static String get role => (data['role'] ?? 'both') as String;
  static bool get sells => role != 'buy';
  static bool get buys => role != 'sell';
  static List<String> get materials => List<String>.from((data['materials'] ?? const []) as List);
  /// "+201000000001", from the hidden login name "201000000001@phone.feedtech.app".
  static String get phone {
    final u = FirebaseAuth.instance.currentUser;
    final login = u?.email ?? '';
    return u?.phoneNumber ?? (login.contains('@') ? '+${login.split('@').first}' : '');
  }
}

// ── Catalogue (the `materials` collection) ──────────────────────────────────

class Commodity {
  Commodity(this.id, Json m)
      : name = m['name'] as String,
        icon = (m['icon'] ?? '') as String,
        specs = [for (final s in (m['specs'] ?? const []) as List) SpecDef.fromMap(s as Map)];
  final String id, name, icon;
  final List<SpecDef> specs;
}

class Catalog {
  static List<Commodity> all = [];
  static Future<void> load() async {
    final q = await db.collection('materials').orderBy('order').get();
    all = [for (final d in q.docs) Commodity(d.id, d.data())];
  }

  static Commodity byId(String id) => all.firstWhere((c) => c.id == id, orElse: () => Commodity(id, {'name': id}));
}

IconData commodityIcon(String key) => switch (key) {
      'eco' => Icons.eco,
      'grain' => Icons.grain,
      'grass' => Icons.grass,
      'bran' => Icons.scatter_plot,
      _ => Icons.inventory_2,
    };

/// "بروتين 46% · رطوبة 12% · برازيلي". For a request, limits read "أو أكتر" / "أو أقل".
String specText(String materialId, Map? specs, {bool request = false}) {
  final parts = <String>[];
  for (final d in Catalog.byId(materialId).specs) {
    final v = specs?[d.key];
    if (v == null) continue;
    parts.add(switch (d.kind) {
      'min' => '${d.label} ${d.show(v)}${request ? ' أو أكتر' : ''}',
      'max' => '${d.label} ${d.show(v)}${request ? ' أو أقل' : ''}',
      _ => '$v',
    });
  }
  return parts.isEmpty ? (request ? 'أي مواصفات' : '') : parts.join(' · ');
}

// ── Places, payment, roles ─────────────────────────────────────────────────

/// Industrial areas and cities (with their governorate) used for company location and delivery place.
const areas = <(String, String)>[
  ('العاشر من رمضان', 'الشرقية'),
  ('السادات', 'المنوفية'),
  ('العبور', 'القليوبية'),
  ('6 أكتوبر', 'الجيزة'),
  ('برج العرب', 'الإسكندرية'),
  ('بدر', 'القاهرة'),
  ('القاهرة', 'القاهرة'),
  ('الإسكندرية', 'الإسكندرية'),
  ('الجيزة', 'الجيزة'),
  ('قويسنا', 'المنوفية'),
  ('بنها', 'القليوبية'),
  ('الزقازيق', 'الشرقية'),
  ('المنصورة', 'الدقهلية'),
  ('طنطا', 'الغربية'),
  ('دمنهور', 'البحيرة'),
  ('الإسماعيلية', 'الإسماعيلية'),
  ('الفيوم', 'الفيوم'),
  ('بني سويف', 'بني سويف'),
  ('المنيا', 'المنيا'),
  ('أسيوط', 'أسيوط'),
  ('سوهاج', 'سوهاج'),
];

String governorateOf(String area) => areas.where((a) => a.$1 == area).firstOrNull?.$2 ?? '';

String areaLabel(String area) {
  final g = governorateOf(area);
  return g.isEmpty || g == area ? area : '$area (محافظة $g)';
}

const payments = {'cash': 'كاش', 'transfer': 'تحويل بنكي', 'deferred': 'آجل'};
const paymentIcons = {'cash': Icons.payments_outlined, 'transfer': Icons.account_balance, 'deferred': Icons.event_note};
const roles = {'buy': 'بنشتري خامات', 'sell': 'بنبيع خامات', 'both': 'بنشتري وبنبيع'};

// ── Arabic formatting (Western digits, as traders write prices) ─────────────

final _n = NumberFormat.decimalPattern('en');
String fmt(num v) => _n.format(v);
String perTon(num v) => '${fmt(v)} جنيه للطن';
String tons(num v) => '${fmt(v)} طن';

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String dateText(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "النهارده", "بكرة", or "الخميس 4 ديسمبر".
String dayLabel(DateTime d) {
  final days = daysUntil(d, DateTime.now());
  final sameDay = dayKey(d) == dayKey(DateTime.now());
  if (sameDay) return 'النهارده';
  if (days == 1) return 'بكرة';
  return '${_weekdays[d.weekday - 1]} ${dateText(d)}';
}

/// "دلوقتي", "من 5 دقايق", "من ساعتين", "امبارح", "من 3 أيام".
String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'دلوقتي';
  if (m < 60) return m == 1 ? 'من دقيقة' : (m == 2 ? 'من دقيقتين' : (m <= 10 ? 'من $m دقايق' : 'من $m دقيقة'));
  final h = m ~/ 60;
  if (h < 24) return h == 1 ? 'من ساعة' : (h == 2 ? 'من ساعتين' : (h <= 10 ? 'من $h ساعات' : 'من $h ساعة'));
  final d = h ~/ 24;
  if (d == 1) return 'امبارح';
  if (d == 2) return 'من يومين';
  return d <= 10 ? 'من $d أيام' : 'يوم ${dateText(t)}';
}

/// "+1,000 جنيه عن ميزانيتك" / "أقل من ميزانيتك بـ 500 جنيه" / "نفس ميزانيتك".
String budgetDiff(int over) => over > 0
    ? '+${fmt(over)} جنيه عن ميزانيتك'
    : (over < 0 ? 'أقل من ميزانيتك بـ ${fmt(-over)} جنيه' : 'نفس ميزانيتك بالظبط');

/// Delivery choices shown as big buttons (days from today).
const deliveryChoices = <(int, String)>[
  (0, 'النهارده'),
  (1, 'بكرة'),
  (2, 'بعد يومين'),
  (7, 'خلال أسبوع'),
  (14, 'خلال أسبوعين'),
];

int dayMillis(int daysFromToday) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + daysFromToday).millisecondsSinceEpoch;
}

// ── Queries ────────────────────────────────────────────────────────────────

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

// ── Drafts: nothing the user typed is lost if they leave a form ─────────────

/// Best effort: a storage problem must never break a form, so failures are only logged.
class Drafts {
  static Future<Json?> load(String key) async {
    try {
      final s = (await SharedPreferences.getInstance()).getString('draft:$key');
      return s == null ? null : jsonDecode(s) as Json;
    } catch (e) {
      debugPrint('draft load failed: $e');
      return null;
    }
  }

  static Future<void> save(String key, Json v) async {
    try {
      await (await SharedPreferences.getInstance()).setString('draft:$key', jsonEncode(v));
    } catch (e) {
      debugPrint('draft save failed: $e');
    }
  }

  static Future<void> clear(String key) async {
    try {
      await (await SharedPreferences.getInstance()).remove('draft:$key');
    } catch (e) {
      debugPrint('draft clear failed: $e');
    }
  }
}

// ── Photos ─────────────────────────────────────────────────────────────────
// shortcut: photos are stored compressed (≤ ~500 KB) in Firestore because the project is on the
// free Spark plan, where Firebase Storage needs Blaze. Move them to Storage after upgrading.

final _photoCache = <String, Uint8List>{};

Future<String> savePhoto(Uint8List bytes) async {
  final ref = await db.collection('photos').add({'owner': myUid, 'data': base64Encode(bytes), 'at': FieldValue.serverTimestamp()});
  _photoCache[ref.id] = bytes;
  return ref.id;
}

Future<Uint8List?> loadPhoto(String id) async {
  if (_photoCache.containsKey(id)) return _photoCache[id];
  final d = await db.collection('photos').doc(id).get();
  final data = d.data()?['data'];
  if (data is! String) return null;
  return _photoCache[id] = base64Decode(data);
}

// ── Writes ─────────────────────────────────────────────────────────────────

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
