import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../deal_rules.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';
import 'profile.dart';

/// "دورك ترد" / "مستني رد ..." / "اتفقتوا ✓" for a negotiation.
class StatusLine extends StatelessWidget {
  const StatusLine(this.n, {super.key});
  final Json n;
  @override
  Widget build(BuildContext context) => switch (n['status']) {
        'negotiating' => myTurn(n)
            ? const Pill('دورك ترد على السعر ده', icon: Icons.reply, color: C.amber, bg: C.amberBg)
            : Pill('مستني رد ${otherCompany(n)}', icon: Icons.hourglass_top, color: C.blue, bg: C.blueBg),
        'agreed' => Pill(n['orderId'] == null ? 'اتفقتوا ✓ فاضل الطلبية' : 'اتفقتوا ✓ واتعملت طلبية', icon: Icons.handshake),
        'declined' => const Pill('العرض اترفض', icon: Icons.block, color: C.red, bg: C.redBg),
        _ => const Pill('التفاوض اتلغى', icon: Icons.cancel_outlined, color: C.muted, bg: Color(0xFFE2E8F0)),
      };
}

Future<void> acceptFlow(BuildContext context, Doc n) async {
  final d = n.data()!;
  final ok = await confirm(context,
      'هتوافق على ${perTon(d['price'] as num)} لـ ${tons(d['qty'] as num)}؟\nالإجمالي ${fmt((d['price'] as num) * (d['qty'] as num))} جنيه',
      yes: 'أيوه، موافق');
  if (!ok || !context.mounted) return;
  if (await attempt(context, () => negotiate(n, DealAction.accept)) && context.mounted) {
    showDone(context, d['buyerId'] == myUid ? 'اتفقتوا ✓ كمّل الطلبية دلوقتي' : 'اتفقتوا ✓ مستنيين المصنع يكمّل الطلبية');
  }
}

Future<void> counterFlow(BuildContext context, Doc n) async {
  final d = n.data()!;
  var price = (d['price'] as num).toInt(), qty = (d['qty'] as num).toInt();
  final send = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.9),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
            Text('اعرض سعر تاني', style: tt(c).headlineSmall),
            Text('آخر سعر: ${perTon(d['price'] as num)}', style: tt(c).bodyMedium),
            const SizedBox(height: 12),
            NumberStepper(
              value: price,
              step: 50,
              min: 100,
              unit: 'جنيه للطن',
              quick: const [-500, -100, 100, 500],
              quickRelative: true,
              onChanged: (x) => setSheet(() => price = x),
            ),
            const SizedBox(height: 16),
            Text('الكمية', style: tt(c).titleMedium),
            NumberStepper(value: qty, step: 5, min: 1, unit: 'طن', onChanged: (x) => setSheet(() => qty = x)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ابعت السعر')),
          ]),
        ),
      ),
    ),
  );
  if (send != true || !context.mounted) return;
  if (await attempt(context, () => negotiate(n, DealAction.counter, price: price, qty: qty)) && context.mounted) {
    showDone(context, 'بعتنا سعرك ✓ هيوصلك تنبيه لما يرد');
  }
}

const _stepWords = {'offer': 'عرض', 'counter': 'سعر جديد', 'accept': 'وافق', 'decline': 'رفض', 'cancel': 'لغى'};

/// One negotiation: summary, current price, the full history, and what this user can do now.
class NegotiationScreen extends StatelessWidget {
  const NegotiationScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => LiveDoc(db.doc('negotiations/$id'), builder: (context, doc) {
        final n = doc.data()!;
        final c = Catalog.byId(n['materialId'] as String);
        final iAmBuyer = n['buyerId'] == myUid;
        final status = DealStatus.values.byName(n['status'] as String);
        final lastMine = n['lastBy'] == myUid;
        bool can(DealAction a) => nextStatus(status, a, actorMadeLastOffer: lastMine) != null;
        return Scaffold(
          appBar: AppBar(title: Text('مفاوضة ${c.name}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    onTap: () => open(context, ProfileScreen(uid: otherId(n))),
                    child: InfoRow(iAmBuyer ? Icons.storefront : Icons.factory_outlined, iAmBuyer ? 'التاجر' : 'المصنع',
                        otherCompany(n)),
                  ),
                  InfoRow(commodityIcon(c.icon), 'الخامة', '${c.name} ${specText(c.id, n['specs'] as Map?)}'),
                  InfoRow(Icons.event, 'التسليم', dayLabel(timeOf(n['deliveryDate']))),
                  InfoRow(Icons.place_outlined, 'المكان', areaLabel(n['place'] as String)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: C.greenBg,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('آخر سعر', style: tt(context).bodyMedium),
                  PriceText(n['price'] as num, big: true),
                  Text('${tons(n['qty'] as num)} · الإجمالي ${fmt((n['price'] as num) * (n['qty'] as num))} جنيه',
                      style: tt(context).titleSmall),
                  const SizedBox(height: 8),
                  StatusLine(n),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('سجل التفاوض', style: tt(context).titleLarge),
            const SizedBox(height: 8),
            Live(doc.reference.collection('steps').orderBy('at'), builder: (context, steps) => Column(children: [
                  for (final s in steps)
                    Align(
                      alignment: s.data()['by'] == myUid ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: s.data()['by'] == myUid ? C.blueBg : Colors.white,
                          border: Border.all(color: C.line, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s.data()['by'] == myUid ? 'انت' : otherCompany(n)}: ${_stepWords[s.data()['kind']] ?? ''}',
                              style: tt(context).titleSmall),
                          Text('${perTon(s.data()['price'] as num)} · ${tons(s.data()['qty'] as num)}', style: tt(context).bodyMedium),
                          if ((s.data()['note'] ?? '').toString().isNotEmpty) Text(s.data()['note'] as String, style: tt(context).bodyMedium),
                          Text(ago(timeOf(s.data()['at'])), style: tt(context).bodySmall),
                        ]),
                      ),
                    ),
                ])),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (can(DealAction.accept))
                  FilledButton.icon(
                      onPressed: () => acceptFlow(context, doc), icon: const Icon(Icons.check), label: const Text('اقبل السعر')),
                if (can(DealAction.counter)) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => counterFlow(context, doc), child: const Text('اعرض سعر تاني')),
                ],
                if (can(DealAction.decline))
                  TextButton(
                    onPressed: () async {
                      if (await confirm(context, 'ترفض العرض ده؟') && context.mounted) {
                        if (await attempt(context, () => negotiate(doc, DealAction.decline)) && context.mounted) {
                          showDone(context, 'رفضنا العرض');
                        }
                      }
                    },
                    child: const Text('ارفض'),
                  )
                else if (can(DealAction.cancel))
                  TextButton(
                    onPressed: () async {
                      if (await confirm(context, 'تسحب عرضك وتلغي التفاوض؟') && context.mounted) {
                        if (await attempt(context, () => negotiate(doc, DealAction.cancel)) && context.mounted) {
                          showDone(context, 'لغينا التفاوض');
                        }
                      }
                    },
                    child: const Text('اسحب عرضي'),
                  ),
                if (status == DealStatus.agreed)
                  n['orderId'] != null
                      ? FilledButton(
                          onPressed: () => open(context, OrderScreen(id: n['orderId'] as String)), child: const Text('افتح الطلبية'))
                      : iAmBuyer
                          ? FilledButton.icon(
                              onPressed: () => open(context, OrderFormScreen(nego: doc)),
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('كمّل الطلبية'),
                            )
                          : Text('مستنيين المصنع يكمّل الطلبية', style: tt(context).titleSmall, textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      });
}

class NegotiationsScreen extends StatelessWidget {
  const NegotiationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المفاوضات')),
        body: Live(myNegotiations, builder: (context, negos) {
          if (negos.isEmpty) {
            return const MessageView(
              icon: Icons.handshake_outlined,
              title: 'مفيش مفاوضات لسه',
              text: 'لما تبعت سعر على إعلان أو عرض على طلب هيظهر هنا',
            );
          }
          // Waiting for me first, then the rest by latest activity.
          final list = newest(negos, 'updatedAt')..sort((a, b) => (myTurn(b.data()) ? 1 : 0) - (myTurn(a.data()) ? 1 : 0));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final n in list)
              ActionRow(
                icon: commodityIcon(Catalog.byId(n.data()['materialId'] as String).icon),
                title: '${otherCompany(n.data())} · ${Catalog.byId(n.data()['materialId'] as String).name}',
                sub: '${perTon(n.data()['price'] as num)} · ${tons(n.data()['qty'] as num)} · ${switch (n.data()['status']) {
                  'negotiating' => myTurn(n.data()) ? 'دورك ترد' : 'مستني رده',
                  'agreed' => 'اتفقتوا ✓',
                  'declined' => 'اترفض',
                  _ => 'اتلغى',
                }}',
                badge: myTurn(n.data()) ? 1 : 0,
                onTap: () => open(context, NegotiationScreen(id: n.id)),
              ),
          ]);
        }),
      );
}

/// After both sides agree, the buyer completes the order: quantity and price are fixed by
/// the agreement; payment, delivery day and place can be changed here.
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, required this.nego});
  final Doc nego;
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  late final Json n = widget.nego.data()!;
  late String _payment = n['payment'] as String;
  late int _date = timeOf(n['deliveryDate']).millisecondsSinceEpoch;
  late String _place = n['place'] as String;
  bool _busy = false;

  Widget _row(IconData icon, String label, String value, VoidCallback? onChange) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(children: [
              Expanded(child: InfoRow(icon, label, value)),
              if (onChange != null) TextButton(onPressed: onChange, child: const Text('غيّر')),
            ]),
          ),
        ),
      );

  Future<void> _send() async {
    setState(() => _busy = true);
    String? id;
    final ok = await attempt(context, () async => id = await createOrder(widget.nego, payment: _payment, dateMs: _date, place: _place));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    showDone(context, 'تم إرسال الطلبية ✓ أول ما ${n['sellerCompany']} يأكدها هيظهرلك رقم تليفونه');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderScreen(id: id!)));
  }

  @override
  Widget build(BuildContext context) {
    final c = Catalog.byId(n['materialId'] as String);
    final qty = (n['qty'] as num).toInt(), price = (n['price'] as num).toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('كمّل الطلبية')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('راجع الطلبية وابعتها لـ ${n['sellerCompany']}', style: tt(context).titleMedium),
        const SizedBox(height: 12),
        _row(commodityIcon(c.icon), 'الخامة', '${c.name} ${specText(c.id, n['specs'] as Map?)}', null),
        _row(Icons.inventory_2_outlined, 'الكمية', tons(qty), null),
        _row(Icons.sell_outlined, 'السعر المتفق عليه', perTon(price), null),
        _row(Icons.payments_outlined, 'الإجمالي', '${fmt(qty * price)} جنيه', null),
        _row(paymentIcons[_payment] ?? Icons.payments, 'الدفع', payments[_payment] ?? _payment, () async {
          final p = await pickOption<String>(context, 'هتدفع إزاي؟',
              [for (final e in payments.entries) Opt(e.key, e.value, icon: paymentIcons[e.key])], _payment);
          if (p != null) setState(() => _payment = p);
        }),
        _row(Icons.event, 'يوم التسليم', dayLabel(DateTime.fromMillisecondsSinceEpoch(_date)), () async {
          final d = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (c) => SafeArea(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
                Text('يوم التسليم', style: tt(c).headlineSmall),
                const SizedBox(height: 12),
                DatePick(selected: _date, onSelect: (x) => Navigator.pop(c, x)),
              ]),
            ),
          );
          if (d != null) setState(() => _date = d);
        }),
        _row(Icons.place_outlined, 'مكان التسليم', areaLabel(_place), () async {
          final a = await pickOption<String>(context, 'مكان التسليم', areaOptions(), _place);
          if (a != null) setState(() => _place = a);
        }),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : const Text('ابعت الطلبية'),
          ),
        ),
      ),
    );
  }
}

/// One order: where it is (جديدة → مؤكدة → اتسلمت), its details, the other side's phone once confirmed.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => LiveDoc(db.doc('orders/$id'), builder: (context, doc) {
        final o = doc.data()!;
        final c = Catalog.byId(o['materialId'] as String);
        final isSeller = o['sellerId'] == myUid;
        final status = o['status'] as String;
        final moves = orderMoves(status, isSeller: isSeller);
        return Scaffold(
          appBar: AppBar(title: const Text('الطلبية')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _Tracker(status),
            const SizedBox(height: 16),
            if (status == 'new')
              Text(isSeller ? 'المصنع مستني تأكيدك.' : 'مستنيين ${o['sellerCompany']} يأكد الطلبية.',
                  style: tt(context).titleMedium),
            if (status == 'confirmed' || status == 'delivered') _Contact(order: doc),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow(isSeller ? Icons.factory_outlined : Icons.storefront, isSeller ? 'المصنع' : 'التاجر', otherCompany(o)),
                  InfoRow(commodityIcon(c.icon), 'الخامة', '${c.name} ${specText(c.id, o['specs'] as Map?)}'),
                  InfoRow(Icons.inventory_2_outlined, 'الكمية', tons(o['qty'] as num)),
                  InfoRow(Icons.sell_outlined, 'السعر', perTon(o['price'] as num)),
                  InfoRow(Icons.payments_outlined, 'الإجمالي', '${fmt(o['total'] as num)} جنيه'),
                  InfoRow(paymentIcons[o['payment']] ?? Icons.payments, 'الدفع', payments[o['payment']] ?? ''),
                  InfoRow(Icons.event, 'يوم التسليم', dayLabel(timeOf(o['deliveryDate']))),
                  InfoRow(Icons.place_outlined, 'مكان التسليم', areaLabel(o['place'] as String)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => open(context, NegotiationScreen(id: o['negotiationId'] as String)),
              icon: const Icon(Icons.history),
              label: const Text('شوف سجل التفاوض'),
            ),
          ]),
          bottomNavigationBar: moves.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final m in moves)
                        if (m == 'cancelled')
                          TextButton(
                            onPressed: () async {
                              if (await confirm(context, 'تلغي الطلبية دي؟ هنبلّغ ${otherCompany(o)}.') && context.mounted) {
                                if (await attempt(context, () => moveOrder(doc, m)) && context.mounted) {
                                  showDone(context, 'لغينا الطلبية');
                                }
                              }
                            },
                            child: const Text('الغي الطلبية'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () async {
                              if (await attempt(context, () => moveOrder(doc, m)) && context.mounted) {
                                showDone(context, m == 'confirmed' ? 'أكّدنا الطلبية ✓ رقم المصنع ظهرلك' : 'سجلنا إن البضاعة اتسلمت ✓');
                              }
                            },
                            icon: Icon(m == 'confirmed' ? Icons.check : Icons.inventory),
                            label: Text(m == 'confirmed' ? 'أكّد الطلبية' : 'البضاعة اتسلمت'),
                          ),
                    ]),
                  ),
                ),
        );
      });
}

class _Tracker extends StatelessWidget {
  const _Tracker(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const Pill('الطلبية دي اتلغت', icon: Icons.cancel_outlined, color: C.red, bg: C.redBg);
    }
    const steps = ['new', 'confirmed', 'delivered'];
    final at = steps.indexOf(status);
    return Row(children: [
      for (final (i, s) in steps.indexed) ...[
        Expanded(
          child: Column(children: [
            Icon(i <= at ? Icons.check_circle : Icons.radio_button_unchecked, size: 36, color: i <= at ? C.green : C.muted),
            Text(orderLabels[s]!, style: tt(context).labelMedium?.copyWith(color: i <= at ? C.green : C.muted)),
          ]),
        ),
      ],
    ]);
  }
}

/// The other side's phone and a big call button (only readable after confirmation, by the rules).
class _Contact extends StatelessWidget {
  const _Contact({required this.order});
  final Doc order;
  @override
  Widget build(BuildContext context) {
    final o = order.data()!;
    return FutureBuilder<DocumentSnapshot<Json>>(
      future: order.reference.collection('contacts').doc(otherId(o)).get(),
      builder: (context, s) {
        final phone = s.data?.data()?['phone'] as String?;
        if (phone == null) return const SizedBox();
        return Card(
          color: C.blueBg,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('رقم ${otherCompany(o)}', style: tt(context).bodyMedium),
              Text(phone, style: tt(context).headlineSmall, textDirection: TextDirection.ltr, textAlign: TextAlign.end),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                icon: const Icon(Icons.call),
                label: const Text('اتصل'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الطلبيات')),
        body: Live(myOrders, builder: (context, orders) {
          if (orders.isEmpty) {
            return const MessageView(
              icon: Icons.local_shipping_outlined,
              title: 'مفيش طلبيات لسه',
              text: 'لما تتفق على سعر وتكمّل الطلبية هتظهر هنا',
            );
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final o in newest(orders, 'updatedAt'))
              ActionRow(
                icon: commodityIcon(Catalog.byId(o.data()['materialId'] as String).icon),
                title: '${otherCompany(o.data())} · ${tons(o.data()['qty'] as num)} ${Catalog.byId(o.data()['materialId'] as String).name}',
                sub: 'الطلبية ${orderLabels[o.data()['status']]} · ${fmt(o.data()['total'] as num)} جنيه',
                badge: o.data()['status'] == 'new' && o.data()['sellerId'] == myUid ? 1 : 0,
                onTap: () => open(context, OrderScreen(id: o.id)),
              ),
          ]);
        }),
      );
}
