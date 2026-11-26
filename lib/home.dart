import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'deal.dart';
import 'post_offer.dart';

typedef Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

final _db = FirebaseFirestore.instance;

/// My deals: as a buyer or as a seller, depending on the demo account.
Query<Map<String, dynamic>> myDeals(Business me) =>
    _db.collection('deals').where(me.isSeller ? 'sellerId' : 'buyerId', isEqualTo: me.id);

bool _live(Map<String, dynamic> x) => (x['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now());

/// Builds [child] from a live query, with loading and error states.
Widget _stream(Query<Map<String, dynamic>> q, Widget Function(List<Doc> docs) child) =>
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return child(snap.data!.docs);
      },
    );

Widget _empty(String text) =>
    Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.me});
  final Business me;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final fab = switch ((_tab, me.isSeller)) {
      (0, true) => FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('نشر عرض'),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostOfferScreen(seller: me))),
        ),
      (1, false) => FloatingActionButton.extended(
          icon: const Icon(Icons.request_quote),
          label: const Text('اطلب عرض سعر'),
          onPressed: () => _newRfq(context, me),
        ),
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(me.name)),
      floatingActionButton: fab,
      body: [MarketTab(me: me), RequestsTab(me: me), DealsTab(me: me)][_tab],
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: myDeals(me).snapshots(),
        builder: (context, snap) {
          // Badge = deals waiting for my answer.
          final waiting = (snap.data?.docs ?? const <Doc>[])
              .where((d) => d['status'] == 'negotiating' && d['lastOfferBy'] != me.id)
              .length;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.storefront), label: 'أسعار السوق'),
              NavigationDestination(
                  icon: const Icon(Icons.request_quote), label: me.isSeller ? 'طلبات المصانع' : 'طلباتي'),
              NavigationDestination(
                icon: Badge(isLabelVisible: waiting > 0, label: Text('$waiting'), child: const Icon(Icons.handshake)),
                label: 'الصفقات',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Market prices ───────────────────────────────────────────────────────────

class MarketTab extends StatefulWidget {
  const MarketTab({super.key, required this.me});
  final Business me;

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  String? _productId; // null = all products

  Future<void> _order(Map<String, dynamic> l) async {
    final me = widget.me;
    final r = await askPriceQty(
      context,
      title: 'طلب شراء · ${l['productName']}',
      hint: 'السعر المعروض ${fmt(l['price'])} ج/طن. تقدر تعرض سعر أقل.',
      price: l['price'],
      qty: l['minQty'],
      minQty: l['minQty'],
      maxQty: l['qty'],
    );
    if (r == null || !mounted) return;
    final (price, qty) = r;
    await guarded(context, () async {
      final id = await startDeal(
        buyer: me,
        seller: businessById(l['sellerId']),
        by: me,
        productName: l['productName'],
        spec: l['spec'],
        price: price,
        qty: qty,
      );
      if (mounted) openDeal(context, me, id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final (id, name) in [(null, 'الكل'), for (final p in demoProducts) (p.id, p.name)])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(name),
                  selected: _productId == id,
                  onSelected: (_) => setState(() => _productId = id),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        // Live: a listing posted on the other phone appears here at once. Cheapest first.
        child: _stream(_db.collection('listings').orderBy('price'), (all) {
          // shortcut: filtering on the phone is fine for demo volumes; use indexed queries for real data.
          final docs = all
              .where((d) =>
                  d['status'] == 'active' && _live(d.data()) && (_productId == null || d['productId'] == _productId))
              .toList();
          if (docs.isEmpty) return _empty('مفيش عروض النهارده · اطلب عرض سعر');
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88), // room for the floating button
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final l = docs[i].data();
              final mine = l['sellerId'] == widget.me.id;
              return ListingCard(
                data: l,
                mine: mine,
                onTap: widget.me.isSeller ? null : () => _order(l),
              );
            },
          );
        }),
      ),
    ]);
  }
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.data, this.mine = false, this.onTap});
  final Map<String, dynamic> data;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hoursLeft = (data['expiresAt'] as Timestamp).toDate().difference(DateTime.now()).inHours;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('${data['productName']} · ${data['spec']}', style: t.titleMedium)),
                Text('${fmt(data['price'])} ج/طن', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.verified, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(child: Text('${data['sellerName']}')),
                if (mine) const Chip(label: Text('عرضك'), visualDensity: VisualDensity.compact),
              ]),
              Text(
                '${fmt(data['qty'])} طن متاح · أقل كمية ${data['minQty']} طن · ${data['governorate']}',
                style: t.bodySmall,
              ),
              Text('${data['payment']} · ${data['delivery']} · ينتهي بعد $hoursLeft ساعة', style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Requests for quotation ──────────────────────────────────────────────────

Future<void> _newRfq(BuildContext context, Business me) async {
  var product = demoProducts.first;
  var spec = product.specs.first;
  var payment = paymentOptions.first;
  final qtyC = TextEditingController(text: '50');
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('طلب عرض سعر'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Product>(
              value: product,
              decoration: const InputDecoration(labelText: 'المنتج'),
              items: [for (final p in demoProducts) DropdownMenuItem(value: p, child: Text(p.name))],
              onChanged: (p) => setState(() {
                product = p!;
                spec = p.specs.first;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(product.id), // reset when the product changes
              value: spec,
              decoration: const InputDecoration(labelText: 'المواصفة'),
              items: [for (final s in product.specs) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (s) => setState(() => spec = s!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية (طن)'),
              validator: validateAmount,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: payment,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: [for (final p in paymentOptions) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (p) => setState(() => payment = p!),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => form.currentState!.validate() ? Navigator.pop(ctx, true) : null,
            child: const Text('إرسال للموردين'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await guarded(
    context,
    () => _db.collection('rfqs').add({
      'buyerId': me.id,
      'buyerName': me.name,
      'governorate': me.governorate,
      'productId': product.id,
      'productName': product.name,
      'spec': spec,
      'qty': parseAmount(qtyC.text),
      'payment': payment,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    }),
  );
}

class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key, required this.me});
  final Business me;

  @override
  Widget build(BuildContext context) {
    final rfqs = me.isSeller
        ? _db.collection('rfqs').where('status', isEqualTo: 'open')
        : _db.collection('rfqs').where('buyerId', isEqualTo: me.id);
    // Deals carry the quotes: a quote is a deal opened from a request (rfqId).
    return _stream(myDeals(me), (deals) {
      final quotesByRfq = <String, List<Doc>>{};
      for (final d in deals) {
        if (d.data().containsKey('rfqId')) (quotesByRfq[d['rfqId']] ??= []).add(d);
      }
      return _stream(rfqs, (all) {
        final list = all.where((r) => _live(r.data())).toList();
        if (list.isEmpty) {
          return _empty(me.isSeller
              ? 'مفيش طلبات من المصانع دلوقتي'
              : 'اطلب عرض سعر، والموردين هيبعتولك أسعارهم هنا');
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final r in list)
              me.isSeller
                  ? _SellerRfqCard(me: me, rfq: r, myQuote: quotesByRfq[r.id]?.first)
                  : _BuyerRfqCard(me: me, rfq: r, quotes: quotesByRfq[r.id] ?? const []),
          ],
        );
      });
    });
  }
}

String _rfqTitle(Doc r) => '${r['productName']} · ${r['spec']} · ${fmt(r['qty'])} طن';

class _BuyerRfqCard extends StatelessWidget {
  const _BuyerRfqCard({required this.me, required this.rfq, required this.quotes});
  final Business me;
  final Doc rfq;
  final List<Doc> quotes;

  @override
  Widget build(BuildContext context) {
    final sorted = [...quotes]..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          title: Text(_rfqTitle(rfq)),
          subtitle: Text(sorted.isEmpty ? 'في انتظار عروض الموردين…' : '${sorted.length} عروض · الأرخص الأول'),
        ),
        for (final (i, q) in sorted.indexed)
          ListTile(
            leading: Icon(i == 0 ? Icons.star : Icons.local_offer_outlined, color: i == 0 ? Colors.amber : null),
            title: Text(q['sellerName']),
            subtitle: Text(statusLabels[q['status']]!),
            trailing: Text('${fmt(q['price'])} ج/طن',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            onTap: () => openDeal(context, me, q.id),
          ),
      ]),
    );
  }
}

class _SellerRfqCard extends StatelessWidget {
  const _SellerRfqCard({required this.me, required this.rfq, this.myQuote});
  final Business me;
  final Doc rfq;
  final Doc? myQuote;

  Future<void> _quote(BuildContext context) async {
    final r = await askPriceQty(context, title: 'عرض سعر · ${rfq['productName']}', qty: rfq['qty']);
    if (r == null || !context.mounted) return;
    final (price, qty) = r;
    await guarded(context, () async {
      final id = await startDeal(
        buyer: businessById(rfq['buyerId']),
        seller: me,
        by: me,
        productName: rfq['productName'],
        spec: rfq['spec'],
        price: price,
        qty: qty,
        rfqId: rfq.id,
      );
      if (context.mounted) openDeal(context, me, id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = myQuote;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(_rfqTitle(rfq)),
        subtitle: Text('${rfq['buyerName']} · ${rfq['governorate']} · ${rfq['payment']}'),
        trailing: q == null
            ? FilledButton(onPressed: () => _quote(context), child: const Text('قدّم سعر'))
            : OutlinedButton(
                onPressed: () => openDeal(context, me, q.id),
                child: Text('عرضك ${fmt(q['price'])}'),
              ),
      ),
    );
  }
}

// ── Deals ───────────────────────────────────────────────────────────────────

class DealsTab extends StatelessWidget {
  const DealsTab({super.key, required this.me});
  final Business me;

  @override
  Widget build(BuildContext context) {
    return _stream(myDeals(me), (all) {
      if (all.isEmpty) return _empty('لسه مفيش صفقات');
      // Newest activity first; a just-written deal has no server time yet, so it counts as now.
      DateTime at(Doc d) => (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final deals = [...all]..sort((a, b) => at(b).compareTo(at(a)));
      return ListView(children: [
        for (final d in deals)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text('${d['productName']} · ${d['spec']}'),
              subtitle: Text(
                  '${me.isSeller ? d['buyerName'] : d['sellerName']} · ${fmt(d['qty'])} طن · ${statusLabels[d['status']]}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt(d['price'])} ج/طن', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (d['status'] == 'negotiating' && d['lastOfferBy'] != me.id)
                    Text('دورك', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
              onTap: () => openDeal(context, me, d.id),
            ),
          ),
      ]);
    });
  }
}
