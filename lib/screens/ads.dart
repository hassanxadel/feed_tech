import 'package:flutter/material.dart';

import '../data.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';
import 'market.dart';

/// Today's average price of a material from current ads (used to pre-fill price steppers).
Future<int?> marketAverage(String materialId) async {
  final q = await activeAds.where('materialId', isEqualTo: materialId).get();
  final now = DateTime.now();
  return statsOf([
    for (final a in q.docs)
      if (!isStale(timeOf(a.data()['priceAt']), now)) (a.data()['price'] as num).toInt(),
  ])?.avg;
}

/// "اعرض بضاعتك": material → specs → quantity → minimum order → price → place → terms → photos and publish.
class AdFlow extends StatefulWidget {
  const AdFlow({super.key});
  @override
  State<AdFlow> createState() => _AdFlowState();
}

class _AdFlowState extends State<AdFlow> with DraftForm {
  bool _busy = false;
  int? _avg;
  @override
  String get draftKey => 'ad';
  @override
  Json defaults() => {
        'materialId': null,
        'specs': <String, dynamic>{},
        'qty': 100,
        'minOrder': 10,
        'price': null,
        'area': Me.area,
        'payments': <String>['cash'],
        'delivers': false,
        'deliveryDays': 1,
        'photos': <String>[],
        'notes': '',
      };

  Commodity? get _c => v['materialId'] == null ? null : Catalog.byId(v['materialId'] as String);
  Map get _specs => v['specs'] as Map;

  Future<void> _next() async {
    final c = _c;
    final problem = switch (step) {
      1 => c == null ? 'اختار الخامة الأول' : null,
      2 => c!.specs.any((s) => _specs[s.key] == null) ? 'اختار كل المواصفات' : null,
      7 => (v['payments'] as List).isEmpty ? 'اختار طريقة دفع واحدة على الأقل' : null,
      _ => null,
    };
    if (problem != null) return showProblem(context, problem);
    if (step == 4 && (v['minOrder'] as int) > (v['qty'] as int)) {
      return showProblem(context, 'أقل طلبية لازم تكون أقل من الكمية المتاحة');
    }
    if (step == 1) {
      _avg = await marketAverage(c!.id);
      if (!mounted) return;
      if (v['price'] == null) set('price', _avg ?? 20000);
    }
    if (step < 8) return go(step + 1);
    setState(() => _busy = true);
    String? id;
    final ok = await attempt(context, () async => id = await publishAd(v));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Drafts.clear(draftKey);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DoneScreen(
        title: 'تم نشر إعلانك ✓',
        text: 'المصانع بتشوف سعرك دلوقتي. حدّث السعر كل يوم من "إعلاناتي" علشان تفضل في أول النتايج.',
        primary: 'شوف إعلانك',
        onPrimary: (c) => Navigator.of(c).pushReplacement(MaterialPageRoute(builder: (_) => AdScreen(id: id!))),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return StepFlow(
      title: 'اعرض بضاعتك',
      step: step,
      total: 8,
      busy: _busy,
      banner: restoredBanner,
      nextLabel: step == 8 ? 'انشر الإعلان' : 'التالي',
      onNext: _next,
      onBack: back,
      child: switch (step) {
        1 => Column(children: [
            const Ask('بتبيع إيه؟'),
            Options<String>(
              items: [for (final m in Catalog.all) Opt(m.id, m.name, icon: commodityIcon(m.icon))],
              selected: v['materialId'] as String?,
              onSelect: (id) {
                set('materialId', id);
                set('specs', <String, dynamic>{});
                set('price', null);
              },
            ),
          ]),
        2 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Ask('مواصفات ${c!.name}', hint: 'اختار مواصفات البضاعة اللي عندك'),
            for (final s in c.specs) ...[
              Text(s.label, style: tt(context).titleMedium),
              const SizedBox(height: 8),
              ChipPick<Object>(
                items: [for (final o in s.options) Opt(o, s.show(o))],
                selected: _specs[s.key] as Object?,
                onSelect: (o) => set('specs', {..._specs, s.key: o}),
              ),
              const SizedBox(height: 20),
            ],
          ]),
        3 => Column(children: [
            const Ask('عندك كام طن متاح للبيع؟'),
            NumberStepper(
              value: v['qty'] as int,
              step: 25,
              min: 1,
              unit: 'طن',
              quick: const [50, 100, 200, 500],
              onChanged: (x) => set('qty', x),
            ),
          ]),
        4 => Column(children: [
            const Ask('أقل كمية تبيعها في الطلبية؟'),
            NumberStepper(
              value: v['minOrder'] as int,
              step: 5,
              min: 1,
              unit: 'طن',
              quick: const [5, 10, 25, 50],
              onChanged: (x) => set('minOrder', x),
            ),
          ]),
        5 => Column(children: [
            Ask('سعر الطن كام؟',
                hint: _avg == null ? 'السعر للطن بالجنيه' : 'متوسط سعر ${c!.name} في السوق النهارده ${perTon(_avg!)}'),
            NumberStepper(
              value: (v['price'] ?? 20000) as int,
              step: 50,
              min: 100,
              unit: 'جنيه للطن',
              quick: const [-500, -100, 100, 500],
              quickRelative: true,
              onChanged: (x) => set('price', x),
            ),
          ]),
        6 => Column(children: [
            const Ask('البضاعة فين؟'),
            Options<String>(items: areaOptions(), selected: v['area'] as String?, onSelect: (a) => set('area', a)),
          ]),
        7 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Ask('شروط البيع'),
            Text('بتقبل الدفع إزاي؟ (اختار واحدة أو أكتر)', style: tt(context).titleMedium),
            const SizedBox(height: 8),
            for (final p in payments.entries)
              OptionTile(
                multi: true,
                label: p.value,
                icon: paymentIcons[p.key],
                selected: (v['payments'] as List).contains(p.key),
                onTap: () {
                  final l = List<String>.from(v['payments'] as List);
                  l.contains(p.key) ? l.remove(p.key) : l.add(p.key);
                  set('payments', l);
                },
              ),
            const SizedBox(height: 12),
            Text('التسليم', style: tt(context).titleMedium),
            const SizedBox(height: 8),
            Options<bool>(
              items: const [
                Opt(false, 'العميل يستلم من عندنا', icon: Icons.warehouse_outlined),
                Opt(true, 'بنوصّل لحد المصنع', icon: Icons.local_shipping_outlined),
              ],
              selected: v['delivers'] as bool,
              onSelect: (x) => set('delivers', x),
            ),
            if (v['delivers'] == true) ...[
              Text('بتقدر توصّل خلال قد إيه؟', style: tt(context).titleMedium),
              const SizedBox(height: 8),
              ChipPick<int>(
                items: const [Opt(0, 'نفس اليوم'), Opt(1, 'يوم'), Opt(3, '3 أيام'), Opt(7, 'أسبوع')],
                selected: v['deliveryDays'] as int,
                onSelect: (x) => set('deliveryDays', x),
              ),
            ],
          ]),
        _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Ask('راجع إعلانك', hint: 'ممكن تضيف صور للبضاعة (مش لازم)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow(commodityIcon(c!.icon), 'الخامة', c.name),
                  InfoRow(Icons.science_outlined, 'المواصفات', specText(c.id, _specs)),
                  InfoRow(Icons.sell_outlined, 'السعر', perTon(v['price'] as int)),
                  InfoRow(Icons.inventory_2_outlined, 'الكمية', '${tons(v['qty'] as int)} · أقل طلبية ${tons(v['minOrder'] as int)}'),
                  InfoRow(Icons.place_outlined, 'المكان', areaLabel(v['area'] as String)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('صور البضاعة', style: tt(context).titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final p in v['photos'] as List)
                Stack(children: [
                  PhotoBox(p as String, size: 100),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: IconButton.filled(
                      tooltip: 'شيل الصورة',
                      style: IconButton.styleFrom(backgroundColor: C.red),
                      icon: const Icon(Icons.close),
                      onPressed: () => set('photos', List<String>.from(v['photos'] as List)..remove(p)),
                    ),
                  ),
                ]),
              if ((v['photos'] as List).length < 4)
                InkWell(
                  onTap: () async {
                    final id = await addPhoto(context);
                    if (id != null) set('photos', [...v['photos'] as List, id]);
                  },
                  child: const PhotoBox(null, size: 100, icon: Icons.add_a_photo_outlined, label: 'ضيف صورة'),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('notes$restored'),
              initialValue: v['notes'] as String,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات (مش لازم)'),
              onChanged: (t) => set('notes', t),
            ),
          ]),
      },
    );
  }
}

/// Change (or confirm) an ad's price and quantity.
Future<void> updatePriceSheet(BuildContext context, Doc ad) async {
  final a = ad.data()!;
  var price = (a['price'] as num).toInt(), qty = (a['qty'] as num).toInt();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.9),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
            Text('سعر ${Catalog.byId(a['materialId'] as String).name} النهارده', style: tt(c).headlineSmall),
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
            Text('الكمية المتاحة', style: tt(c).titleMedium),
            NumberStepper(value: qty, step: 25, min: 1, unit: 'طن', onChanged: (x) => setSheet(() => qty = x)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('احفظ')),
          ]),
        ),
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  if (await attempt(context, () => updateAdPrice(ad, price, qty)) && context.mounted) {
    showDone(context, 'تم تحديث السعر ✓');
  }
}

/// "إعلاناتي": confirm today's price in one tap, change it, or pause the ad.
class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إعلاناتي')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => open(context, const AdFlow()),
          icon: const Icon(Icons.add),
          label: const Text('إعلان جديد'),
        ),
        body: Live(myAdsQuery, builder: (context, docs) {
          if (docs.isEmpty) {
            return MessageView(
              icon: Icons.sell_outlined,
              title: 'لسه معندكش إعلانات',
              text: 'اعرض بضاعتك وسعرك والمصانع هتشوفه وتبعتلك',
              action: 'اعرض بضاعتك',
              onAction: () => open(context, const AdFlow()),
            );
          }
          final today = dayKey(DateTime.now());
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            Text('حدّث أسعارك كل يوم علشان تفضل في أول النتايج.', style: tt(context).bodyMedium),
            const SizedBox(height: 12),
            for (final d in newest(docs))
              AdCard(
                id: d.id,
                ad: d.data(),
                extra: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (d.data()['active'] != true)
                    const Pill('الإعلان واقف، المصانع مش شايفاه', icon: Icons.pause, color: C.amber, bg: C.amberBg)
                  else if (dayKey(timeOf(d.data()['priceAt'])) != today) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        if (await attempt(context,
                                () => updateAdPrice(d, (d.data()['price'] as num).toInt(), (d.data()['qty'] as num).toInt())) &&
                            context.mounted) {
                          showDone(context, 'تمام، أكّدنا سعرك النهارده ✓');
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('السعر زي ما هو'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => updatePriceSheet(context, d),
                    icon: const Icon(Icons.edit),
                    label: const Text('غيّر السعر أو الكمية'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final active = d.data()['active'] == true;
                      if (active && !await confirm(context, 'توقف الإعلان ده؟ المصانع مش هتشوفه لحد ما تشغّله تاني.')) return;
                      if (!context.mounted) return;
                      if (await attempt(context, () => d.reference.update({'active': !active})) && context.mounted) {
                        showDone(context, active ? 'وقفنا الإعلان' : 'الإعلان رجع يظهر ✓');
                      }
                    },
                    child: Text(d.data()['active'] == true ? 'وقّف الإعلان' : 'شغّل الإعلان تاني'),
                  ),
                ]),
              ),
          ]);
        }),
      );
}

/// Shown after publishing something: a clear confirmation and what happens next.
class DoneScreen extends StatelessWidget {
  const DoneScreen(
      {super.key, required this.title, required this.text, required this.primary, required this.onPrimary, this.child});
  final String title, text, primary;
  final void Function(BuildContext) onPrimary;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const Text('تمام')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.check_circle, color: C.green, size: 96),
          const SizedBox(height: 8),
          Text(title, style: tt(context).headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text, style: tt(context).bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => onPrimary(context), child: Text(primary)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.home_outlined),
            label: const Text('رجوع للرئيسية'),
          ),
          if (child != null) ...[const SizedBox(height: 28), child!],
        ]),
      );
}
