import 'package:flutter/material.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/models/commodity.dart';
import 'package:feedtech/models/me.dart';
import 'package:feedtech/presentation/screens/ads/ads_screens.dart';
import 'package:feedtech/presentation/screens/deals/deals_screens.dart';
import 'package:feedtech/presentation/screens/home/home_screens.dart';
import 'package:feedtech/presentation/screens/profile/profile_screens.dart';
import 'package:feedtech/presentation/screens/requests/requests_screens.dart';
import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/presentation/widgets/info_widgets.dart';
import 'package:feedtech/presentation/widgets/photos.dart';
import 'package:feedtech/presentation/widgets/pickers.dart';
import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/services/queries.dart';
import 'package:feedtech/shared/constants/app_constants.dart';
import 'package:feedtech/shared/constants/app_theme.dart';
import 'package:feedtech/shared/utils/formatters.dart';

/// Browse sellers' ads: pick a material, sort, and (optionally) filter by price, place and quantity.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, this.materialId});
  final String? materialId;
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late String? _mat = widget.materialId;
  String _sort = 'cheap';
  int? _maxPrice;
  String? _area;
  int? _minQty;

  int get _filters => [_maxPrice, _area, _minQty].where((f) => f != null).length;

  Future<void> _filter(List<QDoc> ads) async {
    final prices = [for (final a in ads) (a.data()['price'] as num).toInt()];
    var maxPrice = _maxPrice ?? (prices.isEmpty ? 25000 : prices.reduce((a, b) => a > b ? a : b));
    var useMax = _maxPrice != null;
    var area = _area;
    var minQty = _minQty;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.9),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
              Text('فلترة العروض', style: tt(c).headlineSmall),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('حد أقصى للسعر', style: tt(c).titleMedium),
                value: useMax,
                onChanged: (x) => setSheet(() => useMax = x),
              ),
              if (useMax)
                NumberStepper(
                  value: maxPrice,
                  step: 100,
                  unit: 'جنيه للطن أو أقل',
                  quick: const [-1000, -500, 500, 1000],
                  quickRelative: true,
                  onChanged: (x) => setSheet(() => maxPrice = x),
                ),
              const SizedBox(height: 16),
              Text('أقل كمية متاحة', style: tt(c).titleMedium),
              const SizedBox(height: 8),
              ChipPick<int?>(
                items: const [Opt(null, 'أي كمية'), Opt(50, '50 طن'), Opt(100, '100 طن'), Opt(200, '200 طن')],
                selected: minQty,
                onSelect: (x) => setSheet(() => minQty = x),
              ),
              const SizedBox(height: 16),
              Text('المكان', style: tt(c).titleMedium),
              const SizedBox(height: 8),
              OptionTile(
                label: area == null ? 'أي مكان' : areaLabel(area!),
                icon: Icons.place_outlined,
                selected: area != null,
                onTap: () async {
                  final a = await pickOption<String?>(c, 'المكان', [const Opt(null, 'أي مكان'), ...areaOptions()], area);
                  setSheet(() => area = a);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _maxPrice = useMax ? maxPrice : null;
                    _area = area;
                    _minQty = minQty;
                  });
                  Navigator.pop(c);
                },
                child: const Text('ورّيني النتايج'),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _maxPrice = _area = _minQty = null);
                  Navigator.pop(c);
                },
                child: const Text('امسح الفلترة'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('السوق')),
        body: Live(activeAds, builder: (context, all) {
          final now = DateTime.now();
          final ads = all.where((a) {
            final d = a.data();
            return (_mat == null || d['materialId'] == _mat) &&
                (_maxPrice == null || (d['price'] as num) <= _maxPrice!) &&
                (_area == null || d['area'] == _area) &&
                (_minQty == null || (d['qty'] as num) >= _minQty!);
          }).toList();
          int key(QDoc a) => switch (_sort) {
                'qty' => -(a.data()['qty'] as num).toInt(),
                'near' => a.data()['area'] == Me.area ? 0 : (governorateOf(a.data()['area'] as String) == governorateOf(Me.area) ? 1 : 2),
                _ => (a.data()['price'] as num).toInt(),
              };
          // Current prices first; ads with an old price ("سعر قديم") always go to the end.
          ads.sort((a, b) {
            final sa = isStale(timeOf(a.data()['priceAt']), now), sb = isStale(timeOf(b.data()['priceAt']), now);
            if (sa != sb) return sa ? 1 : -1;
            final k = key(a).compareTo(key(b));
            return k != 0 ? k : (a.data()['price'] as num).compareTo(b.data()['price'] as num);
          });
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            SizedBox(
              height: 60,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final (id, name) in [(null, 'كل الخامات'), for (final c in Catalog.all) (c.id, c.name)])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(label: Text(name), selected: _mat == id, onSelected: (_) => setState(() => _mat = id)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('رتّب حسب', style: tt(context).titleSmall),
            const SizedBox(height: 6),
            ChipPick<String>(
              items: const [Opt('cheap', 'الأرخص'), Opt('near', 'الأقرب ليك'), Opt('qty', 'أكبر كمية')],
              selected: _sort,
              onSelect: (s) => setState(() => _sort = s),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _filter(all),
              icon: const Icon(Icons.tune),
              label: Text(_filters == 0 ? 'فلترة (السعر، المكان، الكمية)' : 'فلترة ($_filters)'),
            ),
            const SizedBox(height: 12),
            Card(
              color: C.greenBg,
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: C.green, size: 32),
                title: const Text('عايز اللي يناسبك بالظبط؟'),
                subtitle: const Text('اكتب طلبك (الكمية والمواصفات والميزانية) ونورّيك التجار المناسبين'),
                onTap: () => open(context, const RequestFlow()),
              ),
            ),
            const SizedBox(height: 16),
            if (ads.isEmpty)
              MessageView(
                icon: Icons.search_off,
                title: 'مفيش عروض بالشروط دي',
                text: 'جرّب تشيل الفلترة، أو اطلب بضاعة والتجار هيبعتولك',
                action: 'اطلب بضاعة',
                onAction: () => open(context, const RequestFlow()),
              )
            else ...[
              Text('لقينا ${ads.length} عرض', style: tt(context).titleMedium),
              const SizedBox(height: 8),
              for (final a in ads) AdCard(id: a.id, ad: a.data()),
            ],
          ]);
        }),
      );
}

class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.id, required this.ad, this.extra});
  final String id;
  final Json ad;
  final Widget? extra;
  @override
  Widget build(BuildContext context) {
    final c = Catalog.byId(ad['materialId'] as String);
    final photos = List<String>.from((ad['photos'] ?? const []) as List);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => open(context, AdScreen(id: id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PhotoBox(photos.firstOrNull, size: 80, icon: commodityIcon(c.icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: tt(context).titleMedium),
                    Text(specText(c.id, ad['specs'] as Map?), style: tt(context).bodySmall),
                    PriceText(ad['price'] as num),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Text('${ad['company']} · ${ad['area']}', style: tt(context).titleSmall),
              Text('متاح ${tons(ad['qty'] as num)} · أقل طلبية ${tons(ad['minOrder'] as num)}', style: tt(context).bodyMedium),
              const SizedBox(height: 8),
              Freshness(ad['priceAt']),
              if (extra != null) ...[const SizedBox(height: 8), extra!],
            ]),
          ),
        ),
      ),
    );
  }
}

/// One seller ad: photos, price, specs, terms, the seller, and "send your price".
class AdScreen extends StatelessWidget {
  const AdScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => LiveDoc(db.doc('ads/$id'), builder: (context, doc) {
        final a = doc.data()!;
        final c = Catalog.byId(a['materialId'] as String);
        final mine = a['sellerId'] == myUid;
        final photos = List<String>.from((a['photos'] ?? const []) as List);
        return Scaffold(
          appBar: AppBar(title: Text(c.name)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SizedBox(
              height: 220,
              child: photos.isEmpty
                  ? Center(child: PhotoBox(null, size: 200, icon: commodityIcon(c.icon), label: 'التاجر لسه منزلش صور'))
                  : PageView(children: [for (final p in photos) Center(child: PhotoBox(p, size: 220))]),
            ),
            if (photos.length > 1) Text('اسحب الصورة يمين وشمال تشوف الباقي', style: tt(context).bodySmall),
            const SizedBox(height: 16),
            PriceText(a['price'] as num, big: true),
            const SizedBox(height: 6),
            Freshness(a['priceAt']),
            if (a['active'] != true) ...[
              const SizedBox(height: 8),
              const Pill('الإعلان ده واقف دلوقتي', icon: Icons.pause_circle_outline, color: C.amber, bg: C.amberBg),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  for (final s in c.specs)
                    if ((a['specs'] as Map?)?[s.key] != null) InfoRow(Icons.science_outlined, s.label, s.show((a['specs'] as Map)[s.key] as Object)),
                  InfoRow(Icons.inventory_2_outlined, 'الكمية المتاحة', tons(a['qty'] as num)),
                  InfoRow(Icons.scale_outlined, 'أقل طلبية', tons(a['minOrder'] as num)),
                  InfoRow(Icons.place_outlined, 'مكان البضاعة', areaLabel(a['area'] as String)),
                  InfoRow(Icons.payments_outlined, 'طرق الدفع',
                      [for (final p in (a['payments'] ?? const []) as List) payments[p] ?? p].join('، ')),
                  InfoRow(
                    Icons.local_shipping_outlined,
                    'التسليم',
                    a['delivers'] == true
                        ? 'بيوصّل لحد المصنع ${(a['deliveryDays'] ?? 0) == 0 ? 'في نفس اليوم' : 'خلال ${a['deliveryDays']} يوم'}'
                        : 'الاستلام من عنده',
                  ),
                  if ((a['notes'] ?? '').toString().isNotEmpty) InfoRow(Icons.notes, 'ملاحظات', a['notes'] as String),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const Icon(Icons.storefront, size: 36),
                title: Text(a['company'] as String),
                subtitle: Text('${a['area']} · اضغط تشوف صفحة الشركة وصورها'),
                onTap: () => open(context, ProfileScreen(uid: a['sellerId'] as String)),
              ),
            ),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: mine
                  ? FilledButton.icon(
                      onPressed: () => updatePriceSheet(context, doc),
                      icon: const Icon(Icons.edit),
                      label: const Text('حدّث السعر'),
                    )
                  : Live(myNegotiations, loading: const SizedBox(height: 60), builder: (context, negos) {
                      final talk = negos.where((n) => n.data()['adId'] == id && n.data()['status'] == 'negotiating').firstOrNull;
                      return talk != null
                          ? FilledButton(
                              onPressed: () => open(context, NegotiationScreen(id: talk.id)), child: const Text('كمّل المفاوضة'))
                          : FilledButton.icon(
                              onPressed: a['active'] == true ? () => open(context, OfferFlow.onAd(id: id, ad: a)) : null,
                              icon: const Icon(Icons.price_change_outlined),
                              label: const Text('اعرض سعرك'),
                            );
                    }),
            ),
          ),
        );
      });
}

/// Ads that fit a buyer's request (see matchAds in logic.dart for the rules).
class MatchesList extends StatelessWidget {
  const MatchesList({super.key, required this.want});
  final Want want;
  @override
  Widget build(BuildContext context) => Live(activeAds.where('materialId', isEqualTo: want.materialId), builder: (context, ads) {
        final matches = matchAds([
          for (final a in ads)
            if (a.data()['sellerId'] != myUid) MapEntry(a.id, a.data())
        ], want, Catalog.byId(want.materialId).specs, DateTime.now());
        if (matches.isEmpty) {
          return const MessageView(
              icon: Icons.search_off,
              title: 'مفيش تجار عندهم الخامة دي دلوقتي',
              text: 'طلبك هيوصلهم أول ما ينزّلوا عروض');
        }
        final full = matches.first.gaps.isEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(full ? '${matches.length} تاجر عندهم اللي انت عايزه' : 'مفيش تطابق كامل. دي أقرب العروض لطلبك:',
              style: tt(context).titleMedium),
          const SizedBox(height: 8),
          for (final m in matches)
            AdCard(
              id: m.id,
              ad: m.ad,
              extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Pill(budgetDiff(m.overBudget),
                    icon: m.overBudget > 0 ? Icons.arrow_upward : Icons.check,
                    color: m.overBudget > 0 ? C.red : C.green,
                    bg: m.overBudget > 0 ? C.redBg : C.greenBg),
                for (final g in [...m.gaps, if (!m.payOk) 'مش بيقبل ${payments[want.payment]}'])
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Pill(g, icon: Icons.info_outline, color: C.amber, bg: C.amberBg),
                  ),
              ]),
            ),
        ]);
      });
}
