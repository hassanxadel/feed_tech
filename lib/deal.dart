import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'deal_rules.dart';
import 'post_offer.dart';

const statusLabels = {
  'negotiating': 'جاري التفاوض',
  'agreed': 'تم الاتفاق',
  'declined': 'مرفوض',
  'cancelled': 'ملغي',
};

Map<String, dynamic> _offer(Business by, int price, int qty) => {
      'by': by.id,
      'byName': by.name,
      'price': price,
      'qty': qty,
      'createdAt': FieldValue.serverTimestamp(),
    };

/// Opens a deal with its first offer in one atomic write and returns the deal id.
/// A buyer ordering from a listing and a seller quoting a request both start here.
Future<String> startDeal({
  required Business buyer,
  required Business seller,
  required Business by,
  required String productName,
  required String spec,
  required int price,
  required int qty,
  String? rfqId,
}) async {
  final db = FirebaseFirestore.instance;
  final deal = db.collection('deals').doc();
  await (db.batch()
        ..set(deal, {
          'buyerId': buyer.id,
          'buyerName': buyer.name,
          'sellerId': seller.id,
          'sellerName': seller.name,
          'productName': productName,
          'spec': spec,
          'price': price,
          'qty': qty,
          'status': 'negotiating',
          'lastOfferBy': by.id,
          if (rfqId != null) 'rfqId': rfqId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..set(deal.collection('offers').doc(), _offer(by, price, qty)))
      .commit();
  return deal.id;
}

/// Asks for a price and a quantity. Returns null when the user cancels.
Future<(int, int)?> askPriceQty(
  BuildContext context, {
  required String title,
  String? hint,
  int? price,
  int? qty,
  int minQty = 1,
  int? maxQty,
}) {
  final priceC = TextEditingController(text: price?.toString() ?? '');
  final qtyC = TextEditingController(text: qty?.toString() ?? '');
  final form = GlobalKey<FormState>();
  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(hint)),
            TextFormField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر (جنيه/طن)'),
              validator: validateAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: qtyC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية (طن)'),
              validator: (v) {
                final error = validateAmount(v);
                if (error != null) return error;
                final n = parseAmount(v!)!;
                if (n < minQty) return 'أقل كمية $minQty طن';
                if (maxQty != null && n > maxQty) return 'المتاح $maxQty طن بس';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, (parseAmount(priceC.text)!, parseAmount(qtyC.text)!));
            }
          },
          child: const Text('إرسال'),
        ),
      ],
    ),
  );
}

/// Shows a failed write instead of letting it vanish.
Future<void> guarded(BuildContext context, Future<void> Function() write) async {
  try {
    await write();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصلت مشكلة، حاول تاني ($e)')));
    }
  }
}

void openDeal(BuildContext context, Business me, String dealId) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => DealScreen(me: me, dealId: dealId)));

class DealScreen extends StatelessWidget {
  const DealScreen({super.key, required this.me, required this.dealId});
  final Business me;
  final String dealId;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('deals').doc(dealId);

  Future<void> _act(BuildContext context, DealAction action, Map<String, dynamic> d) async {
    final status = nextStatus(DealStatus.values.byName(d['status']), action,
        actorMadeLastOffer: d['lastOfferBy'] == me.id)!;
    if (action != DealAction.counter) {
      return guarded(context, () => _ref.update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()}));
    }
    final r = await askPriceQty(context,
        title: 'سعر جديد', hint: 'آخر سعر: ${fmt(d['price'])} ج/طن', price: d['price'], qty: d['qty']);
    if (r == null || !context.mounted) return;
    final (price, qty) = r;
    await guarded(
      context,
      () => (FirebaseFirestore.instance.batch()
            ..update(_ref, {
              'price': price,
              'qty': qty,
              'lastOfferBy': me.id,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            ..set(_ref.collection('offers').doc(), _offer(me, price, qty)))
          .commit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: snap.hasError ? Text('خطأ: ${snap.error}') : const CircularProgressIndicator()),
          );
        }
        final myTurnOver = d['lastOfferBy'] == me.id;
        final other = me.isSeller ? d['buyerName'] : d['sellerName'];
        final current = DealStatus.values.byName(d['status']);
        final actions = [
          for (final a in DealAction.values)
            if (nextStatus(current, a, actorMadeLastOffer: myTurnOver) != null) a,
        ];
        return Scaffold(
          appBar: AppBar(title: Text('${d['productName']} · ${d['spec']}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text('مع: $other', style: t.titleMedium)),
                        Chip(label: Text(statusLabels[d['status']]!)),
                      ]),
                      Text('${fmt(d['price'])} ج/طن · ${fmt(d['qty'])} طن',
                          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('الإجمالي: ${fmt(d['price'] * d['qty'])} جنيه', style: t.bodyMedium),
                    ],
                  ),
                ),
              ),
              if (current == DealStatus.agreed)
                Card(
                  color: Colors.green.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.handshake, color: Colors.green, size: 36),
                    title: Text('تم الاتفاق'),
                    subtitle: Text('الصفقة متسجلة عند الطرفين بكل تفاصيل التفاوض'),
                  ),
                )
              else if (current == DealStatus.negotiating && myTurnOver)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('في انتظار رد $other', style: t.bodyMedium),
                ),
              const SizedBox(height: 16),
              Text('سجل التفاوض', style: t.titleMedium),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _ref.collection('offers').orderBy('createdAt').snapshots(),
                builder: (context, offers) => Column(children: [
                  for (final o in offers.data?.docs ?? const [])
                    ListTile(
                      leading: Icon(o['by'] == me.id ? Icons.north_east : Icons.south_west),
                      title: Text(o['by'] == me.id ? 'أنت' : o['byName']),
                      subtitle: Text('${fmt(o['price'])} ج/طن · ${fmt(o['qty'])} طن'),
                    ),
                ]),
              ),
            ],
          ),
          bottomNavigationBar: actions.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final a in actions)
                          switch (a) {
                            DealAction.accept => FilledButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('قبول'),
                                onPressed: () => _act(context, a, d)),
                            DealAction.counter => OutlinedButton(
                                onPressed: () => _act(context, a, d), child: const Text('سعر جديد')),
                            DealAction.decline => TextButton(
                                onPressed: () => _act(context, a, d), child: const Text('رفض')),
                            DealAction.cancel => TextButton(
                                onPressed: () => _act(context, a, d),
                                child: Text(myTurnOver ? 'سحب العرض' : 'إلغاء')),
                          },
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
