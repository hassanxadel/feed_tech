import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ads.dart';
import 'deals.dart';
import 'home.dart';
import 'market.dart';
import 'requests.dart';

/// A company page: info, logo, product photos. Your own page also has your lists and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) => LiveDoc(db.doc('users/$uid'), builder: (context, doc) {
        final u = doc.data()!;
        final mine = uid == myUid;
        final gallery = List<String>.from((u['gallery'] ?? const []) as List);
        final mats = List<String>.from((u['materials'] ?? const []) as List);
        return Scaffold(
          appBar: AppBar(title: Text(mine ? 'حسابي' : (u['company'] ?? '') as String)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            Row(children: [
              PhotoBox(u['logo'] as String?, size: 92, circle: true, icon: Icons.factory_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((u['company'] ?? '') as String, style: tt(context).headlineSmall),
                  Text((u['name'] ?? '') as String, style: tt(context).bodyMedium),
                  Text(areaLabel((u['area'] ?? '') as String), style: tt(context).bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Pill(roles[u['role']] ?? '', icon: Icons.business_center_outlined, color: C.blue, bg: C.blueBg),
              if (((u['years'] ?? 0) as num) > 0) Pill('في السوق من ${u['years']} سنة', icon: Icons.history_edu),
              for (final m in mats) Pill(Catalog.byId(m).name, icon: commodityIcon(Catalog.byId(m).icon)),
            ]),
            if ((u['about'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('عن الشركة', style: tt(context).titleMedium),
              Text(u['about'] as String, style: tt(context).bodyLarge),
            ],
            if (mine) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => open(context, EditProfileScreen(profile: u)),
                icon: const Icon(Icons.edit),
                label: const Text('عدّل بيانات الشركة'),
              ),
            ],
            const SizedBox(height: 24),
            Text('صور المنتجات', style: tt(context).titleLarge),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final p in gallery)
                InkWell(onTap: () => _viewPhoto(context, p, mine ? doc : null), child: PhotoBox(p, size: 104)),
              if (mine)
                InkWell(
                  onTap: () async {
                    final id = await addPhoto(context);
                    if (id == null || !context.mounted) return;
                    if (await attempt(context, () => doc.reference.update({'gallery': FieldValue.arrayUnion([id])})) &&
                        context.mounted) {
                      showDone(context, 'ضفنا الصورة ✓');
                    }
                  },
                  child: const PhotoBox(null, size: 104, icon: Icons.add_a_photo_outlined, label: 'ضيف صورة'),
                )
              else if (gallery.isEmpty)
                for (var i = 0; i < 2; i++) const PhotoBox(null, size: 104),
            ]),
            const SizedBox(height: 24),
            if (mine) ...[
              Text('شغلي', style: tt(context).titleLarge),
              const SizedBox(height: 10),
              if (Me.sells)
                ActionRow(icon: Icons.sell_outlined, title: 'إعلاناتي', sub: 'أسعارك والكميات', onTap: () => open(context, const MyAdsScreen())),
              if (Me.buys)
                ActionRow(
                    icon: Icons.assignment_outlined, title: 'طلباتي', sub: 'اللي طلبته والعروض عليه', onTap: () => open(context, const MyRequestsScreen())),
              ActionRow(icon: Icons.handshake_outlined, title: 'المفاوضات', sub: 'كل الأسعار اللي اتبعتت', onTap: () => open(context, const NegotiationsScreen())),
              ActionRow(icon: Icons.local_shipping_outlined, title: 'الطلبيات', sub: 'من التأكيد لحد التسليم', onTap: () => open(context, const OrdersScreen())),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.red, width: 2)),
                onPressed: () async {
                  if (!await confirm(context, 'تخرج من حسابك؟ هتدخل تاني برقم موبايلك والرقم السري.', yes: 'أيوه، اخرج')) return;
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ] else ...[
              Text('إعلانات الشركة', style: tt(context).titleLarge),
              const SizedBox(height: 10),
              Live(activeAds.where('sellerId', isEqualTo: uid), builder: (context, ads) => ads.isEmpty
                  ? Text('مفيش إعلانات دلوقتي', style: tt(context).bodyMedium)
                  : Column(children: [for (final a in ads) AdCard(id: a.id, ad: a.data())])),
            ],
          ]),
        );
      });

  void _viewPhoto(BuildContext context, String id, Doc? ownProfile) => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(8), child: PhotoBox(id, size: MediaQuery.of(c).size.width - 60)),
            if (ownProfile != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: C.red),
                onPressed: () async {
                  Navigator.pop(c);
                  if (await confirm(context, 'تشيل الصورة دي؟') && context.mounted) {
                    await attempt(context, () => ownProfile.reference.update({'gallery': FieldValue.arrayRemove([id])}));
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('شيل الصورة'),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('اقفل')),
          ]),
        ),
      );
}

/// Edit company info. Saved as a draft while typing, so nothing is lost.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Json profile;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with DraftForm {
  bool _busy = false;
  @override
  String get draftKey => 'profile';
  @override
  Json defaults() => {
        'company': widget.profile['company'] ?? '',
        'name': widget.profile['name'] ?? '',
        'area': widget.profile['area'] ?? Me.area,
        'role': widget.profile['role'] ?? 'both',
        'years': ((widget.profile['years'] ?? 0) as num).toInt(),
        'about': widget.profile['about'] ?? '',
        'materials': List<String>.from((widget.profile['materials'] ?? const []) as List),
        'logo': widget.profile['logo'],
      };

  Widget _field(String key, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          key: ValueKey('$key$restored'),
          initialValue: v[key] as String,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
          onChanged: (t) => set(key, t),
        ),
      );

  Future<void> _save() async {
    if ((v['company'] as String).trim().length < 2) return showProblem(context, 'اكتب اسم الشركة');
    setState(() => _busy = true);
    final ok = await attempt(context, () => db.doc('users/$myUid').update({
          'company': (v['company'] as String).trim(),
          'name': (v['name'] as String).trim(),
          'area': v['area'],
          'role': v['role'],
          'years': v['years'],
          'about': (v['about'] as String).trim(),
          'materials': v['materials'],
          'logo': v['logo'],
        }));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Drafts.clear(draftKey);
    showDone(context, 'تم حفظ بياناتك ✓');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بيانات الشركة')),
        body: Column(children: [
          if (restoredBanner != null) restoredBanner!,
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                child: InkWell(
                  onTap: () async {
                    final id = await addPhoto(context);
                    if (id != null) set('logo', id);
                  },
                  child: Column(children: [
                    PhotoBox(v['logo'] as String?, size: 104, circle: true, icon: Icons.add_a_photo_outlined),
                    Text('غيّر اللوجو', style: tt(context).labelMedium?.copyWith(color: C.green)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              _field('company', 'اسم الشركة أو المصنع'),
              _field('name', 'اسمك'),
              OptionTile(
                icon: Icons.place_outlined,
                label: areaLabel(v['area'] as String),
                sub: 'المكان (اضغط علشان تغيّره)',
                selected: false,
                onTap: () async {
                  final a = await pickOption<String>(context, 'المكان', areaOptions(), v['area'] as String?);
                  if (a != null) set('area', a);
                },
              ),
              Text('شغلكم', style: tt(context).titleMedium),
              const SizedBox(height: 8),
              ChipPick<String>(
                items: [for (final r in roles.entries) Opt(r.key, r.value)],
                selected: v['role'] as String?,
                onSelect: (r) => set('role', r),
              ),
              const SizedBox(height: 16),
              Text('الخامات اللي بتتعاملوا فيها', style: tt(context).titleMedium),
              const SizedBox(height: 8),
              for (final c in Catalog.all)
                OptionTile(
                  multi: true,
                  icon: commodityIcon(c.icon),
                  label: c.name,
                  selected: (v['materials'] as List).contains(c.id),
                  onTap: () {
                    final l = List<String>.from(v['materials'] as List);
                    l.contains(c.id) ? l.remove(c.id) : l.add(c.id);
                    set('materials', l);
                  },
                ),
              Text('في السوق من كام سنة؟', style: tt(context).titleMedium),
              NumberStepper(value: v['years'] as int, min: 0, max: 100, unit: 'سنة', onChanged: (x) => set('years', x)),
              const SizedBox(height: 16),
              _field('about', 'نبذة عن الشركة (مش لازم)', lines: 4),
            ]),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('احفظ'),
            ),
          ),
        ),
      );
}
