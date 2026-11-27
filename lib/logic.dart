// Pure business rules (no UI, no network): matching, price freshness, daily stats, order steps.
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// A seller's price counts as current for 48 hours after its last update; after that the ad
/// shows "سعر قديم", drops below fresh ads and leaves the daily average.
const staleAfter = Duration(hours: 48);

bool isStale(DateTime priceAt, DateTime now) => now.difference(priceAt) > staleAfter;

/// Firestore time → DateTime. A write still waiting for the server counts as "now".
DateTime timeOf(Object? t) => t is Timestamp ? t.toDate() : (t is DateTime ? t : DateTime.now());

String _two(int n) => n.toString().padLeft(2, '0');

/// Calendar day key used for daily price documents, e.g. "2026-11-27".
String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Whole calendar days from [now] until [date] (0 = today), never negative.
int daysUntil(DateTime date, DateTime now) => math.max(
    0, DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays);

/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits → Western digits.
String westernDigits(String text) => String.fromCharCodes(text.runes.map((c) => c >= 0x660 && c <= 0x669
    ? c - 0x660 + 0x30
    : (c >= 0x6F0 && c <= 0x6F9 ? c - 0x6F0 + 0x30 : c)));

/// Reads a whole number typed on any keyboard: "24900", "24,900", "٢٤٬٩٠٠". Null if not a number.
int? parseAmount(String text) {
  final t = westernDigits(text).trim().replaceAll(RegExp('[,٬ ]'), '');
  return RegExp(r'^\d+$').hasMatch(t) ? int.tryParse(t) : null;
}

/// One specification field of a material, defined in the `materials` collection.
/// kind: "min" (higher is better, e.g. protein), "max" (lower is better, e.g. moisture), "choice" (e.g. origin).
class SpecDef {
  const SpecDef(this.key, this.label, this.kind, this.unit, this.options);
  factory SpecDef.fromMap(Map m) =>
      SpecDef(m['key'], m['label'], m['kind'], (m['unit'] ?? '') as String, List<Object>.from(m['options']));
  final String key, label, kind, unit;
  final List<Object> options;

  String show(Object v) => unit.isEmpty ? '$v' : '$v$unit';
}

/// Does a seller's product ([have]) meet a buyer's requirements ([want])? A null requirement means "any".
bool specsMeet(List<SpecDef> defs, Map have, Map want) => defs.every((d) {
      final w = want[d.key];
      if (w == null) return true;
      final h = have[d.key];
      if (h == null) return false;
      return switch (d.kind) {
        'min' => (h as num) >= (w as num),
        'max' => (h as num) <= (w as num),
        _ => h == w,
      };
    });

class Stats {
  const Stats(this.avg, this.min, this.max, this.count);
  final int avg, min, max, count;
}

/// Average (rounded to 10 EGP), lowest, highest and count of a set of prices; null when empty.
Stats? statsOf(Iterable<int> prices) {
  final l = prices.toList();
  if (l.isEmpty) return null;
  final avg = l.reduce((a, b) => a + b) / l.length;
  return Stats((avg / 10).round() * 10, l.reduce(math.min), l.reduce(math.max), l.length);
}

/// What a buyer is looking for (the request form).
class Want {
  const Want({
    required this.materialId,
    required this.qty,
    required this.budget,
    required this.specs,
    required this.deliveryDate,
    required this.payment,
    required this.area,
  });
  final String materialId, payment, area;
  final int qty, budget;
  final Map specs;
  final DateTime deliveryDate;
}

class AdMatch {
  const AdMatch(this.id, this.ad, this.score, this.overBudget, this.gaps, {required this.stale, required this.payOk});
  final String id;
  final Map<String, dynamic> ad;
  final int score, overBudget; // overBudget: price minus budget (negative = cheaper than budget)
  final List<String> gaps; // why it is not a full match (empty = full match)
  final bool stale, payOk;
}

/// Smart matching. A full match has: the same material, specs that meet the request,
/// enough quantity, a minimum order the buyer reaches, delivery by the requested day,
/// and a price at most 10% above the budget. Ranking (higher first, then cheaper):
/// start at 100, −4 per % above budget, +1 per % below it (up to +10), −20 if the price is stale,
/// −10 if the seller does not take the buyer's payment method, +5 in the same area.
/// When nothing matches fully, the 5 closest ads are returned with what is missing (gaps).
List<AdMatch> matchAds(Iterable<MapEntry<String, Map<String, dynamic>>> ads, Want w, List<SpecDef> defs, DateTime now) {
  final days = daysUntil(w.deliveryDate, now);
  final full = <AdMatch>[], near = <AdMatch>[];
  for (final e in ads) {
    final a = e.value;
    if (a['materialId'] != w.materialId || a['active'] != true) continue;
    final price = (a['price'] as num).toInt();
    final over = price - w.budget;
    final overPct = w.budget > 0 ? over * 100 / w.budget : 0.0;
    final qty = (a['qty'] as num).toInt();
    final minOrder = ((a['minOrder'] ?? 0) as num).toInt();
    final gaps = <String>[
      if (!specsMeet(defs, (a['specs'] ?? const {}) as Map, w.specs)) 'المواصفات مش زي طلبك',
      if (qty < w.qty) 'متاح $qty طن بس',
      if (minOrder > w.qty) 'أقل طلبية عنده $minOrder طن',
      if (((a['deliveryDays'] ?? 0) as num) > days) 'مش هيلحق ميعاد التسليم',
      if (overPct > 10) 'السعر أعلى من ميزانيتك بكتير',
    ];
    final stale = isStale(timeOf(a['priceAt']), now);
    final payOk = List<String>.from((a['payments'] ?? const []) as List).contains(w.payment);
    final score = 100 -
        math.max(overPct, 0) * 4 +
        math.min(math.max(-overPct, 0), 10) -
        (stale ? 20 : 0) -
        (payOk ? 0 : 10) +
        (a['area'] == w.area ? 5 : 0) -
        gaps.length * 25;
    (gaps.isEmpty ? full : near).add(AdMatch(e.key, a, score.round(), over, gaps, stale: stale, payOk: payOk));
  }
  int byScore(AdMatch x, AdMatch y) =>
      y.score != x.score ? y.score.compareTo(x.score) : (x.ad['price'] as num).compareTo(y.ad['price'] as num);
  full.sort(byScore);
  near.sort(byScore);
  return full.isNotEmpty ? full : near.take(5).toList();
}

const orderLabels = {'new': 'جديدة', 'confirmed': 'مؤكدة', 'delivered': 'اتسلمت', 'cancelled': 'اتلغت'};

/// Where an order can go next. The seller confirms a new order; either side marks delivery
/// or cancels before delivery. firestore.rules enforces the same table.
List<String> orderMoves(String status, {required bool isSeller}) => switch (status) {
      'new' => [if (isSeller) 'confirmed', 'cancelled'],
      'confirmed' => ['delivered', 'cancelled'],
      _ => const [],
    };
