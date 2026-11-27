import 'package:flutter/material.dart';

import '../data.dart';
import '../deal_rules.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ads.dart';
import 'deals.dart';
import 'home.dart';
import 'market.dart';
import 'profile.dart';

Want wantOf(Json r) => Want(
      materialId: r['materialId'] as String,
      qty: (r['qty'] as num).toInt(),
      budget: (r['budget'] as num).toInt(),
      specs: (r['specs'] ?? const {}) as Map,
      deliveryDate: r['date'] is int ? DateTime.fromMillisecondsSinceEpoch(r['date'] as int) : timeOf(r['deliveryDate']),
      payment: r['payment'] as String,
      area: r['area'] as String,
    );

/// "اطلب بضاعة": material → quantity → specs → target price → delivery day → place → payment → review.
/// The same answers also drive smart matching (sellers whose ads fit).
class RequestFlow extends StatefulWidget {
  const RequestFlow({super.key});
  @override
  State<RequestFlow> createState() => _RequestFlowState();
}

class _RequestFlowState extends State<RequestFlow> with DraftForm {
  bool _busy = false;
  int? _avg;
  @override
  String get draftKey => 'request';
  @override
  Json defaults() => {
        'materialId': null,
        'qty': 50,
        'specs': <String, dynamic>{},
        'budget': null,
        'date': dayMillis(2),
        'area': Me.area,
        'payment': 'cash',
        'notes': '',
      };

  Commodity? get _c => v['materialId'] == null ? null : Catalog.byId(v['materialId'] as String);

  Future<void> _next() async {
    if (step == 1 && _c == null) return showProblem(context, 'اختار الخامة الأول');
    if (step == 1) {
      _avg = await marketAverage(_c!.id);
      if (!mounted) return;
      if (v['budget'] == null) set('budget', _avg ?? 20000);
    }
    if (step < 8) return go(step + 1);
    setState(() => _busy = true);
    (String, int)? r;
    final ok = await attempt(context, () async => r = await publishRequest(v));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Drafts.clear(draftKey);
    final want = wantOf(v);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DoneScreen(
        title: 'تم نشر طلبك ✓',
        text: r!.$2 == 0
            ? 'أول ما تاجر ${_c!.name} يدخل هيشوف طلبك. هيوصلك تنبيه مع كل عرض.'
            : 'بعتنا طلبك لـ ${r!.$2} تاجر بيبيعوا ${_c!.name}. هيوصلك تنبيه مع كل عرض.',
        primary: 'شوف طلبك والعروض',
        onPrimary: (c) => Navigator.of(c).pushReplacement(MaterialPageRoute(builder: (_) => RequestScreen(id: r!.$1))),
        child: MatchesList(want: want),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final specs = v['specs'] as Map;
    return StepFlow(
      title: 'اطلب بضاعة',
      step: step,
      total: 8,
      busy: _busy,
      banner: restoredBanner,
      nextLabel: step == 8 ? 'انشر الطلب' : 'التالي',
      onNext: _next,
      onBack: back,
      extra: step == 8
          ? TextButton.icon(
              onPressed: () => open(
                  context,
                  Scaffold(
                    appBar: AppBar(title: const Text('التجار المناسبين')),
                    body: ListView(padding: const EdgeInsets.all(16), children: [MatchesList(want: wantOf(v))]),
                  )),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('شوف التجار المناسبين من غير ما تنشر'),
            )
          : null,
      child: switch (step) {
        1 => Column(children: [
            const Ask('محتاج إيه؟'),
            Options<String>(
              items: [for (final m in Catalog.all) Opt(m.id, m.name, icon: commodityIcon(m.icon))],
              selected: v['materialId'] as String?,
              onSelect: (id) {
                set('materialId', id);
                set('specs', <String, dynamic>{});
                set('budget', null);
              },
            ),
          ]),
        2 => Column(children: [
            Ask('محتاج كام طن ${c!.name}؟'),
            NumberStepper(
              value: v['qty'] as int,
              step: 5,
              min: 1,
              unit: 'طن',
              quick: const [10, 25, 50, 100],
              onChanged: (x) => set('qty', x),
            ),
          ]),
        3 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Ask('المواصفات المطلوبة', hint: 'لو مش فارقة معاك سيبها "مش فارقة"'),
            for (final s in c!.specs) ...[
              Text(s.kind == 'min' ? '${s.label} (أقل حاجة)' : (s.kind == 'max' ? '${s.label} (أعلى حاجة)' : s.label),
                  style: tt(context).titleMedium),
              const SizedBox(height: 8),
              ChipPick<Object?>(
                items: [const Opt(null, 'مش فارقة'), for (final o in s.options) Opt(o, s.show(o))],
                selected: specs[s.key] as Object?,
                onSelect: (o) => set('specs', {...specs, s.key: o}),
              ),
              const SizedBox(height: 20),
            ],
          ]),
        4 => Column(children: [
            Ask('عايز تشتري الطن بكام؟',
                hint: _avg == null ? 'السعر اللي في دماغك للطن' : 'متوسط سعر ${c!.name} النهارده ${perTon(_avg!)}'),
            NumberStepper(
              value: (v['budget'] ?? 20000) as int,
              step: 50,
              min: 100,
              unit: 'جنيه للطن',
              quick: const [-500, -100, 100, 500],
              quickRelative: true,
              onChanged: (x) => set('budget', x),
            ),
          ]),
        5 => Column(children: [
            const Ask('محتاجها إمتى؟'),
            DatePick(selected: v['date'] as int?, onSelect: (d) => set('date', d)),
          ]),
        6 => Column(children: [
            const Ask('تتسلّم فين؟'),
            Options<String>(items: areaOptions(), selected: v['area'] as String?, onSelect: (a) => set('area', a)),
          ]),
        7 => Column(children: [
            const Ask('هتدفع إزاي؟'),
            Options<String>(
              items: [for (final p in payments.entries) Opt(p.key, p.value, icon: paymentIcons[p.key])],
              selected: v['payment'] as String?,
              onSelect: (p) => set('payment', p),
            ),
          ]),
        _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Ask('راجع طلبك'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow(commodityIcon(c!.icon), 'الخامة', '${tons(v['qty'] as int)} ${c.name}'),
                  InfoRow(Icons.science_outlined, 'المواصفات', specText(c.id, specs, request: true)),
                  InfoRow(Icons.sell_outlined, 'السعر المستهدف', perTon(v['budget'] as int)),
                  InfoRow(Icons.event, 'التسليم', dayLabel(DateTime.fromMillisecondsSinceEpoch(v['date'] as int))),
                  InfoRow(Icons.place_outlined, 'المكان', areaLabel(v['area'] as String)),
                  InfoRow(paymentIcons[v['payment']]!, 'الدفع', payments[v['payment']]!),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('notes$restored'),
              initialValue: v['notes'] as String,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات للتجار (مش لازم)'),
              onChanged: (t) => set('notes', t),
            ),
          ]),
      },
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary(this.r);
  final Json r;
  @override
  Widget build(BuildContext context) {
    final c = Catalog.byId(r['materialId'] as String);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tons(r['qty'] as num)} ${c.name}', style: tt(context).headlineSmall),
          Text('${r['company']} · ${ago(timeOf(r['createdAt']))}', style: tt(context).bodySmall),
          if (r['open'] != true) ...[
            const SizedBox(height: 6),
            const Pill('الطلب ده اتقفل', icon: Icons.lock_outline, color: C.muted, bg: Color(0xFFE2E8F0)),
          ],
          const Divider(height: 20),
          InfoRow(Icons.science_outlined, 'المواصفات', specText(c.id, r['specs'] as Map?, request: true)),
          InfoRow(Icons.sell_outlined, 'السعر المستهدف', perTon(r['budget'] as num)),
          InfoRow(Icons.event, 'التسليم', dayLabel(timeOf(r['deliveryDate']))),
          InfoRow(Icons.place_outlined, 'مكان التسليم', areaLabel(r['area'] as String)),
          InfoRow(paymentIcons[r['payment']] ?? Icons.payments, 'الدفع', payments[r['payment']] ?? ''),
          if ((r['notes'] ?? '').toString().isNotEmpty) InfoRow(Icons.notes, 'ملاحظات', r['notes'] as String),
        ]),
      ),
    );
  }
}

/// A buyer request. The buyer compares offers and answers them; a seller sends or follows their offer.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => LiveDoc(db.doc('requests/$id'), builder: (context, doc) {
        final r = doc.data()!;
        final mine = r['buyerId'] == myUid;
        return Scaffold(
          appBar: AppBar(title: Text(mine ? 'طلبك' : 'طلب ${r['company']}')),
          body: Live(myNegotiations, builder: (context, negos) {
            final offers = negos.where((n) => n.data()['requestId'] == id).toList()
              ..sort((a, b) => (a.data()['price'] as num).compareTo(b.data()['price'] as num));
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
              _RequestSummary(r),
              const SizedBox(height: 20),
              if (mine) ...[
                SectionTitle('العروض اللي وصلتك (${offers.length})', sub: 'مترتبة من الأرخص للأغلى'),
                if (offers.isEmpty)
                  const MessageView(
                      icon: Icons.hourglass_empty,
                      title: 'لسه مفيش عروض',
                      text: 'بعتنا طلبك للتجار. هيوصلك تنبيه أول ما حد يبعت سعر.')
                else
                  for (final (i, o) in offers.indexed) _OfferCard(doc: o, budget: (r['budget'] as num).toInt(), cheapest: i == 0),
                const SizedBox(height: 24),
                MatchesList(want: wantOf(r)),
                if (r['open'] == true) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      if (!await confirm(context, 'تقفل الطلب؟ التجار مش هيقدروا يبعتوا عروض جديدة عليه.')) return;
                      if (context.mounted && await attempt(context, () => doc.reference.update({'open': false})) && context.mounted) {
                        showDone(context, 'قفلنا الطلب ✓');
                      }
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('اقفل الطلب (لقيت اللي محتاجه)'),
                  ),
                ],
              ] else ...[
                if (offers.isNotEmpty) ...[
                  const SectionTitle('عرضك'),
                  _OfferCard(doc: offers.first, budget: (r['budget'] as num).toInt()),
                ] else if (r['open'] == true)
                  FilledButton.icon(
                    onPressed: () => open(context, OfferFlow.onRequest(id: id, request: r)),
                    icon: const Icon(Icons.price_change_outlined),
                    label: const Text('قدّم عرضك'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => open(context, ProfileScreen(uid: r['buyerId'] as String)),
                  icon: const Icon(Icons.factory_outlined),
                  label: const Text('شوف صفحة المصنع'),
                ),
              ],
            ]);
          }),
        );
      });
}

/// One offer, with the price difference from the budget and the answer buttons right on it.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.doc, required this.budget, this.cheapest = false});
  final QDoc doc;
  final int budget;
  final bool cheapest;
  @override
  Widget build(BuildContext context) {
    final n = doc.data();
    final price = (n['price'] as num).toInt();
    final over = price - budget;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => open(context, NegotiationScreen(id: doc.id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(otherCompany(n), style: tt(context).titleMedium)),
                if (cheapest) const Pill('أرخص عرض', icon: Icons.star),
              ]),
              PriceText(price),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Pill(budgetDiff(over),
                    color: over > 0 ? C.red : C.green, bg: over > 0 ? C.redBg : C.greenBg),
              ),
              const SizedBox(height: 6),
              Text('${tons(n['qty'] as num)} · التسليم ${dayLabel(timeOf(n['deliveryDate']))}', style: tt(context).bodyMedium),
              Text('الإجمالي: ${fmt((n['qty'] as num) * price)} جنيه', style: tt(context).bodyMedium),
              const SizedBox(height: 8),
              StatusLine(n),
              if (n['status'] == 'agreed' && n['orderId'] == null && n['buyerId'] == myUid) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => open(context, OrderFormScreen(nego: doc)),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('كمّل الطلبية'),
                ),
              ],
              if (myTurn(n)) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => acceptFlow(context, doc),
                  icon: const Icon(Icons.check),
                  label: const Text('اقبل العرض'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => counterFlow(context, doc), child: const Text('سعر تاني')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        if (await confirm(context, 'ترفض عرض ${otherCompany(n)}؟') && context.mounted) {
                          if (await attempt(context, () => negotiate(doc, DealAction.decline)) && context.mounted) {
                            showDone(context, 'رفضنا العرض');
                          }
                        }
                      },
                      child: const Text('ارفض'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('طلباتي')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => open(context, const RequestFlow()),
          icon: const Icon(Icons.add),
          label: const Text('طلب جديد'),
        ),
        body: Live(myRequestsQuery, builder: (context, reqs) {
          if (reqs.isEmpty) {
            return MessageView(
              icon: Icons.assignment_outlined,
              title: 'لسه معندكش طلبات',
              text: 'اكتب اللي محتاجه والتجار هيبعتولك أسعارهم',
              action: 'اطلب بضاعة',
              onAction: () => open(context, const RequestFlow()),
            );
          }
          return Live(myNegotiations, builder: (context, negos) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  for (final r in newest(reqs))
                    Builder(builder: (context) {
                      final offers = negos.where((n) => n.data()['requestId'] == r.id);
                      final waiting = offers.where((n) => myTurn(n.data())).length;
                      return ActionRow(
                        icon: commodityIcon(Catalog.byId(r.data()['materialId'] as String).icon),
                        title: '${tons(r.data()['qty'] as num)} ${Catalog.byId(r.data()['materialId'] as String).name}',
                        sub: '${r.data()['open'] == true ? 'مفتوح' : 'مقفول'} · ${offers.length} عرض · ${ago(timeOf(r.data()['createdAt']))}',
                        badge: waiting,
                        onTap: () => open(context, RequestScreen(id: r.id)),
                      );
                    }),
                ],
              ));
        }),
      );
}

/// For sellers: open buyer requests for the materials they sell.
class SellerRequestsScreen extends StatelessWidget {
  const SellerRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('طلبات المصانع')),
        body: Live(openRequests, builder: (context, reqs) => Live(myNegotiations, builder: (context, negos) {
              final mats = Me.materials;
              final quoted = {for (final n in negos) n.data()['requestId']};
              final list = newest(reqs.where((r) =>
                  r.data()['buyerId'] != myUid && (mats.isEmpty || mats.contains(r.data()['materialId']))));
              if (list.isEmpty) {
                return const MessageView(
                  icon: Icons.campaign_outlined,
                  title: 'مفيش طلبات جديدة دلوقتي',
                  text: 'أول ما مصنع يطلب حاجة بتبيعها هيوصلك تنبيه',
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (mats.isNotEmpty)
                  Text('طلبات على: ${mats.map((m) => Catalog.byId(m).name).join('، ')}', style: tt(context).bodyMedium),
                const SizedBox(height: 8),
                for (final r in list)
                  ActionRow(
                    icon: quoted.contains(r.id) ? Icons.check_circle : commodityIcon(Catalog.byId(r.data()['materialId'] as String).icon),
                    title: '${r.data()['company']}: ${tons(r.data()['qty'] as num)} ${Catalog.byId(r.data()['materialId'] as String).name}',
                    sub: '${quoted.contains(r.id) ? 'قدّمت عرض ✓ · ' : ''}عايز ${perTon(r.data()['budget'] as num)} · التسليم ${dayLabel(timeOf(r.data()['deliveryDate']))}',
                    onTap: () => open(context, RequestScreen(id: r.id)),
                  ),
              ]);
            })),
      );
}

/// Send an offer: a seller on a buyer request, or a buyer on a seller ad (at their own price).
class OfferFlow extends StatefulWidget {
  const OfferFlow.onRequest({super.key, required this.id, required Json request})
      : data = request,
        onAd = false;
  const OfferFlow.onAd({super.key, required this.id, required Json ad})
      : data = ad,
        onAd = true;
  final String id;
  final Json data;
  final bool onAd;
  @override
  State<OfferFlow> createState() => _OfferFlowState();
}

class _OfferFlowState extends State<OfferFlow> with DraftForm {
  bool _busy = false;
  Json get d => widget.data;
  @override
  String get draftKey => 'offer:${widget.id}';
  @override
  Json defaults() => {
        'price': ((widget.onAd ? d['price'] : d['budget']) as num).toInt(),
        'qty': ((widget.onAd ? d['minOrder'] : d['qty']) as num).toInt(),
        'date': widget.onAd ? dayMillis((d['deliveryDays'] ?? 1) as int) : timeOf(d['deliveryDate']).millisecondsSinceEpoch,
        'note': '',
      };

  Future<void> _next() async {
    if (step < 4) return go(step + 1);
    setState(() => _busy = true);
    String? nid;
    final ok = await attempt(context, () async {
      nid = await startNegotiation(
        buyerId: widget.onAd ? myUid : d['buyerId'] as String,
        sellerId: widget.onAd ? d['sellerId'] as String : myUid,
        buyerCompany: widget.onAd ? Me.company : d['company'] as String,
        sellerCompany: widget.onAd ? d['company'] as String : Me.company,
        materialId: d['materialId'] as String,
        specs: widget.onAd ? (d['specs'] as Map) : (d['specs'] as Map),
        price: v['price'] as int,
        qty: v['qty'] as int,
        dateMs: v['date'] as int,
        payment: widget.onAd ? ((d['payments'] as List).firstOrNull ?? 'cash') as String : d['payment'] as String,
        place: widget.onAd ? Me.area : d['area'] as String,
        note: v['note'] as String,
        requestId: widget.onAd ? null : widget.id,
        adId: widget.onAd ? widget.id : null,
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Drafts.clear(draftKey);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DoneScreen(
        title: 'تم إرسال عرضك ✓',
        text: 'هيوصلك تنبيه أول ما ${d['company']} يرد.',
        primary: 'شوف المفاوضة',
        onPrimary: (c) => Navigator.of(c).pushReplacement(MaterialPageRoute(builder: (_) => NegotiationScreen(id: nid!))),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Catalog.byId(d['materialId'] as String);
    final ref = ((widget.onAd ? d['price'] : d['budget']) as num).toInt();
    return StepFlow(
      title: widget.onAd ? 'اعرض سعرك' : 'قدّم عرضك',
      step: step,
      total: 4,
      busy: _busy,
      banner: restoredBanner,
      nextLabel: step == 4 ? 'ابعت العرض' : 'التالي',
      onNext: _next,
      onBack: back,
      child: switch (step) {
        1 => Column(children: [
            Ask(widget.onAd ? 'عايز تشتري الطن بكام؟' : 'هتبيع الطن بكام؟',
                hint: widget.onAd ? 'التاجر طالب ${perTon(ref)}' : 'المصنع عايز في حدود ${perTon(ref)}'),
            NumberStepper(
              value: v['price'] as int,
              step: 50,
              min: 100,
              unit: 'جنيه للطن',
              quick: const [-500, -100, 100, 500],
              quickRelative: true,
              onChanged: (x) => set('price', x),
            ),
          ]),
        2 => Column(children: [
            Ask(widget.onAd ? 'عايز كام طن؟' : 'هتورّد كام طن؟',
                hint: widget.onAd
                    ? 'متاح ${tons(d['qty'] as num)}، وأقل طلبية ${tons(d['minOrder'] as num)}'
                    : 'المصنع طالب ${tons(d['qty'] as num)}'),
            NumberStepper(
              value: v['qty'] as int,
              step: 5,
              min: widget.onAd ? (d['minOrder'] as num).toInt() : 1,
              max: widget.onAd ? (d['qty'] as num).toInt() : 100000,
              unit: 'طن',
              onChanged: (x) => set('qty', x),
            ),
          ]),
        3 => Column(children: [
            Ask(widget.onAd ? 'محتاجها إمتى؟' : 'هتسلّم إمتى؟'),
            DatePick(selected: v['date'] as int?, onSelect: (x) => set('date', x)),
          ]),
        _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Ask('راجع عرضك'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow(commodityIcon(c.icon), 'الخامة', c.name),
                  InfoRow(Icons.sell_outlined, 'السعر', perTon(v['price'] as int)),
                  InfoRow(Icons.inventory_2_outlined, 'الكمية', tons(v['qty'] as int)),
                  InfoRow(Icons.payments_outlined, 'الإجمالي', '${fmt((v['price'] as int) * (v['qty'] as int))} جنيه'),
                  InfoRow(Icons.event, 'التسليم', dayLabel(DateTime.fromMillisecondsSinceEpoch(v['date'] as int))),
                  InfoRow(Icons.storefront, widget.onAd ? 'التاجر' : 'المصنع', d['company'] as String),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('note$restored'),
              initialValue: v['note'] as String,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظة (مش لازم)'),
              onChanged: (t) => set('note', t),
            ),
          ]),
      },
    );
  }
}
