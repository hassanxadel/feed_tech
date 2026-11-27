import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ads.dart';
import 'deals.dart';
import 'market.dart';
import 'notifications.dart';
import 'profile.dart';
import 'requests.dart';

void open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});
  final Json profile; // passed so the screen rebuilds when the profile changes
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _dailyReminder();
  }

  /// Once a day, remind a seller whose prices were not confirmed today (in-app notification).
  Future<void> _dailyReminder() async {
    if (!Me.sells) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'reminded-${dayKey(DateTime.now())}';
    if (prefs.getBool(key) == true) return;
    try {
      final ads = await myAdsQuery.where('active', isEqualTo: true).get();
      final today = dayKey(DateTime.now());
      final old = ads.docs.where((a) => dayKey(timeOf(a.data()['priceAt'])) != today).length;
      if (old > 0) {
        await db.collection('notifications').add({
          'to': myUid,
          'from': myUid,
          'type': 'reminder',
          'text': 'صباح الخير! أكّد أو حدّث أسعار إعلاناتك النهارده ($old إعلان) علشان تفضل في أول النتايج',
          'kind': 'myAds',
          'target': '',
          'read': false,
          'at': FieldValue.serverTimestamp(),
        });
      }
      await prefs.setBool(key, true);
    } catch (_) {/* try again next time the app opens */}
  }

  @override
  Widget build(BuildContext context) {
    final buy = BigButton(
      icon: Icons.shopping_cart_outlined,
      title: 'اطلب بضاعة',
      sub: 'اكتب اللي محتاجه، والتجار يبعتولك أسعارهم',
      color: C.green,
      onTap: () => open(context, const RequestFlow()),
    );
    final sell = BigButton(
      icon: Icons.storefront,
      title: 'اعرض بضاعتك',
      sub: 'اعرض منتجك وسعرك لكل المصانع',
      color: C.blue,
      onTap: () => open(context, const AdFlow()),
    );
    final firstName = Me.name.trim();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        titleSpacing: 8,
        title: Row(children: [
          LabeledIcon(icon: Icons.account_circle_outlined, label: 'حسابي', onTap: () => open(context, ProfileScreen(uid: myUid))),
          Live(
            myNotifications.where('read', isEqualTo: false),
            loading: LabeledIcon(icon: Icons.notifications_none, label: 'التنبيهات', onTap: () {}),
            builder: (context, docs) => LabeledIcon(
              icon: Icons.notifications_none,
              label: 'التنبيهات',
              badge: docs.length,
              onTap: () => open(context, const NotificationsScreen()),
            ),
          ),
          const Spacer(),
          const AppLogo(),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        Text(firstName.isEmpty ? 'أهلاً بيك' : 'أهلاً يا $firstName', style: tt(context).headlineSmall),
        Text(Me.company, style: tt(context).bodyMedium?.copyWith(color: C.muted)),
        const SizedBox(height: 12),
        // The big buttons come first so nothing loads above them and moves them under a finger.
        ...(Me.sells && !Me.buys ? [sell, const SizedBox(height: 12), buy] : [buy, const SizedBox(height: 12), sell]),
        const SizedBox(height: 20),
        const _NeedsReply(),
        const SizedBox(height: 8),
        const SectionTitle('أسعار النهارده', sub: 'متوسط سعر الطن من عروض التجار. اضغط على أي خامة تشوف آخر 30 يوم'),
        const _TodayPrices(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => open(context, const MarketScreen()),
          icon: const Icon(Icons.search),
          label: const Text('دوّر على بضاعة في السوق'),
        ),
        const SizedBox(height: 24),
        const SectionTitle('شغلك'),
        const _MyWork(),
        const SizedBox(height: 16),
        const SectionTitle('فيد تك بتساعدك في إيه؟'),
        const _Services(),
      ]),
    );
  }
}

/// Up to 3 things waiting for this user's answer, each one tap away.
class _NeedsReply extends StatelessWidget {
  const _NeedsReply();
  @override
  Widget build(BuildContext context) => Live(myNegotiations, loading: const SizedBox(), builder: (context, negos) {
        return Live(myOrders, loading: const SizedBox(), builder: (context, orders) {
          final items = <Widget>[
            for (final n in newest(negos.where((n) => myTurn(n.data())), 'updatedAt').take(3))
              _ReplyCard(
                text: '${otherCompany(n.data())} ${n.data()['lastBy'] == n.data()['buyerId'] ? 'عرض' : 'بعت سعر'} '
                    '${perTon(n.data()['price'] as num)} على ${Catalog.byId(n.data()['materialId'] as String).name}',
                action: 'رد على العرض',
                onTap: () => open(context, NegotiationScreen(id: n.id)),
              ),
            for (final o in orders.where((o) => o.data()['status'] == 'new' && o.data()['sellerId'] == myUid).take(2))
              _ReplyCard(
                text: 'طلبية جديدة من ${o.data()['buyerCompany']}: ${tons(o.data()['qty'] as num)} '
                    '${Catalog.byId(o.data()['materialId'] as String).name}',
                action: 'أكّد الطلبية',
                onTap: () => open(context, OrderScreen(id: o.id)),
              ),
            for (final n in negos.where((n) =>
                n.data()['status'] == 'agreed' && n.data()['orderId'] == null && n.data()['buyerId'] == myUid))
              _ReplyCard(
                text: 'اتفقت مع ${n.data()['sellerCompany']} — فاضل تكمّل الطلبية',
                action: 'كمّل الطلبية',
                onTap: () => open(context, NegotiationScreen(id: n.id)),
              ),
          ];
          if (items.isEmpty) return const SizedBox();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مستنيين ردك', style: tt(context).titleLarge?.copyWith(color: C.red)),
            const SizedBox(height: 8),
            ...items,
          ]);
        });
      });
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.text, required this.action, required this.onTap});
  final String text, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: C.amberBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.amber, width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(text, style: tt(context).titleSmall),
              const SizedBox(height: 10),
              FilledButton(onPressed: onTap, child: Text(action)),
            ]),
          ),
        ),
      );
}

// ── Today's prices ─────────────────────────────────────────────────────────

/// Today's average per material, live from the sellers' current (non-stale) ads,
/// compared with yesterday's saved average.
class _TodayPrices extends StatelessWidget {
  const _TodayPrices();

  static final _saved = <String>{};

  /// Saves today's figure so the 30-day chart has a point for every day the app is used.
  /// shortcut: any signed-in app writes this; move to a scheduled Cloud Function on the Blaze plan.
  static void _saveToday(String materialId, Stats s) {
    final day = dayKey(DateTime.now());
    final sig = '$materialId$day${s.avg}${s.count}${s.min}${s.max}';
    if (!_saved.add(sig)) return;
    db.doc('dailyPrices/${materialId}_$day').set({
      'materialId': materialId,
      'day': day,
      'avg': s.avg,
      'min': s.min,
      'max': s.max,
      'count': s.count,
      'at': FieldValue.serverTimestamp(),
    }).catchError((_) => _saved.remove(sig));
  }

  @override
  Widget build(BuildContext context) {
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    return Live(activeAds, loading: const LoadingView(text: 'بنجيب أسعار النهارده…'), builder: (context, ads) {
      return Live(db.collection('dailyPrices').where('day', isEqualTo: yesterday), builder: (context, ys) {
        final now = DateTime.now();
        return Column(children: [
          for (final c in Catalog.all)
            Builder(builder: (context) {
              final s = statsOf([
                for (final a in ads)
                  if (a.data()['materialId'] == c.id && !isStale(timeOf(a.data()['priceAt']), now))
                    (a.data()['price'] as num).toInt(),
              ]);
              if (s != null) _saveToday(c.id, s);
              final y = ys.where((d) => d.data()['materialId'] == c.id).firstOrNull?.data()['avg'] as num?;
              return _PriceRow(c: c, stats: s, change: s == null || y == null ? null : s.avg - y.toInt());
            }),
        ]);
      });
    });
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.c, required this.stats, required this.change});
  final Commodity c;
  final Stats? stats;
  final int? change;
  @override
  Widget build(BuildContext context) {
    final ch = change;
    final (icon, color, text) = ch == null
        ? (Icons.remove, C.muted, '')
        : ch > 0
            ? (Icons.arrow_upward, C.red, 'زاد ${fmt(ch)} عن امبارح')
            : ch < 0
                ? (Icons.arrow_downward, C.green, 'نزل ${fmt(-ch)} عن امبارح')
                : (Icons.remove, C.muted, 'زي امبارح');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => open(context, PriceScreen(c: c)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(commodityIcon(c.icon), size: 36, color: C.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: tt(context).titleMedium),
                  if (stats == null)
                    Text('مفيش أسعار النهارده', style: tt(context).bodySmall)
                  else ...[
                    PriceText(stats!.avg),
                    if (text.isNotEmpty)
                      Row(children: [
                        Icon(icon, color: color, size: 24),
                        const SizedBox(width: 4),
                        Flexible(child: Text(text, style: tt(context).labelMedium?.copyWith(color: color))),
                      ]),
                  ],
                ]),
              ),
              const Icon(Icons.show_chart, size: 30, color: C.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One material: today's average, lowest and highest, and the last 30 days as a simple chart.
class PriceScreen extends StatelessWidget {
  const PriceScreen({super.key, required this.c});
  final Commodity c;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('سعر ${c.name}')),
        body: Live(activeAds.where('materialId', isEqualTo: c.id), builder: (context, ads) {
          final now = DateTime.now();
          final today = statsOf([
            for (final a in ads)
              if (!isStale(timeOf(a.data()['priceAt']), now)) (a.data()['price'] as num).toInt(),
          ]);
          return Live(db.collection('dailyPrices').where('materialId', isEqualTo: c.id), builder: (context, days) {
            final from = dayKey(now.subtract(const Duration(days: 29)));
            final points = [
              for (final d in days.map((d) => d.data()).toList()..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String)))
                if ((d['day'] as String).compareTo(from) >= 0) (d['day'] as String, (d['avg'] as num).toInt()),
            ];
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (today == null)
                const MessageView(icon: Icons.info_outline, title: 'مفيش أسعار متحدّثة النهارده')
              else ...[
                Text('متوسط النهارده', style: tt(context).bodyMedium),
                PriceText(today.avg, big: true),
                Text('من ${today.count} تاجر', style: tt(context).bodySmall),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MiniStat('أقل سعر النهارده', today.min, C.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat('أعلى سعر النهارده', today.max, C.red)),
                ]),
              ],
              const SizedBox(height: 24),
              Text('السعر في آخر 30 يوم', style: tt(context).titleLarge),
              const SizedBox(height: 8),
              if (points.length < 2)
                Text('لسه مفيش أيام كفاية نرسم بيها', style: tt(context).bodyMedium)
              else
                Card(child: Padding(padding: const EdgeInsets.all(12), child: _Chart(points))),
              const SizedBox(height: 20),
              if (points.isNotEmpty) ...[
                Text('آخر 7 أيام', style: tt(context).titleMedium),
                for (final (day, avg) in points.reversed.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(dayLabel(DateTime.parse(day)), style: tt(context).bodyMedium)),
                      Text(perTon(avg), style: tt(context).titleSmall),
                    ]),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => open(context, MarketScreen(materialId: c.id)),
                icon: const Icon(Icons.search),
                label: Text('شوف عروض ${c.name}'),
              ),
            ]);
          });
        }),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: tt(context).bodySmall),
            FittedBox(child: Text(fmt(value), style: tt(context).headlineSmall?.copyWith(color: color))),
            Text('جنيه للطن', style: tt(context).bodySmall),
          ]),
        ),
      );
}

/// A plain line chart: oldest day on the left, today on the right, lowest and highest marked.
class _Chart extends StatelessWidget {
  const _Chart(this.points);
  final List<(String, int)> points;
  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.$2);
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final first = DateTime.parse(points.first.$1), last = DateTime.parse(points.last.$1);
    return Semantics(
      label: 'السعر كان ${fmt(points.first.$2)} يوم ${dateText(first)} وبقى ${fmt(points.last.$2)} يوم ${dateText(last)}',
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          Row(children: [
            Text(fmt(hi), style: tt(context).labelSmall),
            const Spacer(),
            Text('أعلى', style: tt(context).labelSmall),
          ]),
          SizedBox(height: 180, child: CustomPaint(size: Size.infinite, painter: _ChartPainter(points, lo, hi))),
          Row(children: [
            Text(fmt(lo), style: tt(context).labelSmall),
            const Spacer(),
            Text('أقل', style: tt(context).labelSmall),
          ]),
          const Divider(),
          Row(children: [
            Text(dateText(first), style: tt(context).bodySmall),
            const Spacer(),
            Text(dateText(last), style: tt(context).bodySmall),
          ]),
        ]),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.lo, this.hi);
  final List<(String, int)> points;
  final int lo, hi;
  @override
  void paint(Canvas canvas, Size size) {
    final span = math.max(hi - lo, 1);
    Offset at(int i) => Offset(
        size.width * i / (points.length - 1), size.height - (points[i].$2 - lo) / span * (size.height - 12) - 6);
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      canvas.drawLine(Offset(0, size.height * k / 2), Offset(size.width, size.height * k / 2), grid);
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = C.green
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(at(points.length - 1), 7, Paint()..color = C.green);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}

// ── Your work ──────────────────────────────────────────────────────────────

class _MyWork extends StatelessWidget {
  const _MyWork();
  @override
  Widget build(BuildContext context) => Live(myNegotiations, builder: (context, negos) {
        return Live(myOrders, builder: (context, orders) {
          final talks = negos.where((n) => n.data()['status'] == 'negotiating');
          final waiting = talks.where((n) => myTurn(n.data())).length;
          final active = orders.where((o) => ['new', 'confirmed'].contains(o.data()['status']));
          final toConfirm = orders.where((o) => o.data()['status'] == 'new' && o.data()['sellerId'] == myUid).length;
          return Column(children: [
            if (Me.buys)
              Live(myRequestsQuery, loading: const SizedBox(), builder: (context, reqs) {
                final mine = reqs.where((r) => r.data()['open'] == true).length;
                final offers = negos.where((n) => n.data()['requestId'] != null && n.data()['buyerId'] == myUid && myTurn(n.data())).length;
                return ActionRow(
                  icon: Icons.assignment_outlined,
                  title: 'طلباتي',
                  sub: mine == 0 ? 'معندكش طلبات مفتوحة' : '$mine طلب مفتوح',
                  badge: offers,
                  onTap: () => open(context, const MyRequestsScreen()),
                );
              }),
            if (Me.sells) ...[
              Live(myAdsQuery, loading: const SizedBox(), builder: (context, ads) {
                final old = ads.where((a) =>
                    a.data()['active'] == true && dayKey(timeOf(a.data()['priceAt'])) != dayKey(DateTime.now())).length;
                return ActionRow(
                  icon: Icons.sell_outlined,
                  title: 'إعلاناتي',
                  sub: ads.isEmpty ? 'لسه معندكش إعلانات' : (old > 0 ? '$old إعلان سعره محتاج تأكيد النهارده' : 'كل أسعارك متحدّثة ✓'),
                  badge: old,
                  onTap: () => open(context, const MyAdsScreen()),
                );
              }),
              Live(openRequests, loading: const SizedBox(), builder: (context, reqs) {
                final mats = Me.materials;
                final quoted = {for (final n in negos) n.data()['requestId']};
                final fresh = reqs.where((r) =>
                    r.data()['buyerId'] != myUid &&
                    (mats.isEmpty || mats.contains(r.data()['materialId'])) &&
                    !quoted.contains(r.id)).length;
                return ActionRow(
                  icon: Icons.campaign_outlined,
                  title: 'طلبات المصانع',
                  sub: fresh == 0 ? 'مفيش طلبات جديدة على بضاعتك' : '$fresh طلب جديد على بضاعتك',
                  onTap: () => open(context, const SellerRequestsScreen()),
                );
              }),
            ],
            ActionRow(
              icon: Icons.handshake_outlined,
              title: 'المفاوضات',
              sub: talks.isEmpty ? 'مفيش مفاوضات شغالة' : '${talks.length} مفاوضة شغالة',
              badge: waiting,
              onTap: () => open(context, const NegotiationsScreen()),
            ),
            ActionRow(
              icon: Icons.local_shipping_outlined,
              title: 'الطلبيات',
              sub: active.isEmpty ? 'مفيش طلبيات شغالة' : '${active.length} طلبية شغالة',
              badge: toConfirm,
              onTap: () => open(context, const OrdersScreen()),
            ),
          ]);
        });
      });
}

class _Services extends StatelessWidget {
  const _Services();
  static const _items = [
    (Icons.trending_up, 'أسعار السوق كل يوم', 'متوسط سعر كل خامة والفرق عن امبارح'),
    (Icons.campaign_outlined, 'اطلب مرة واحدة', 'بدل ما تكلم 30 تاجر، اكتب طلبك والتجار يبعتولك'),
    (Icons.handshake_outlined, 'فاوض على السعر', 'ابعت سعرك واتفق من غير مكالمات كتير'),
    (Icons.local_shipping_outlined, 'تابع طلبيتك', 'من التأكيد لحد ما البضاعة توصل'),
  ];
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (icon, title, sub) in _items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 32, color: C.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tt(context).titleSmall),
                  Text(sub, style: tt(context).bodyMedium?.copyWith(color: C.muted)),
                ]),
              ),
            ]),
          ),
      ]);
}
