// Shared, large, labelled widgets so every screen looks and behaves the same.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data.dart';
import 'logic.dart';
import 'theme.dart';

TextTheme tt(BuildContext c) => Theme.of(c).textTheme;

// ── Feedback ────────────────────────────────────────────────────────────────

void showDone(BuildContext context, String text) => _snack(context, text, Icons.check_circle, C.green);
void showProblem(BuildContext context, String text) => _snack(context, text, Icons.error, C.red);

void _snack(BuildContext context, String text, IconData icon, Color color) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(
    backgroundColor: color,
    duration: const Duration(seconds: 5),
    content: Row(children: [
      Icon(icon, color: Colors.white, size: 30),
      const SizedBox(width: 12),
      Expanded(child: Text(text)),
    ]),
  ));

/// A yes/no question in plain words. Returns true only on "yes".
Future<bool> confirm(BuildContext context, String question, {String yes = 'أيوه', String no = 'لأ، رجوع'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(question),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    ) ??
    false;

/// Runs a write, shows a friendly message if it fails. Returns true on success.
Future<bool> attempt(BuildContext context, Future<void> Function() write) async {
  try {
    await write();
    return true;
  } catch (_) {
    if (context.mounted) showProblem(context, 'حصلت مشكلة ومحفظناش. اتأكد إن النت شغال وجرّب تاني.');
    return false;
  }
}

// ── States ──────────────────────────────────────────────────────────────────

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.text = 'لحظة واحدة…'});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox.square(dimension: 48, child: CircularProgressIndicator(strokeWidth: 5)),
            const SizedBox(height: 16),
            Text(text, style: tt(context).bodyLarge),
          ]),
        ),
      );
}

/// Empty and error states: what happened, and what to do next.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.text, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? text, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: C.muted),
            const SizedBox(height: 12),
            Text(title, style: tt(context).titleMedium, textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text!, style: tt(context).bodyMedium?.copyWith(color: C.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}

Widget errorView([VoidCallback? retry]) => MessageView(
      icon: Icons.wifi_off,
      title: 'مش قادرين نجيب البيانات',
      text: 'اتأكد إن النت شغال وجرّب تاني',
      action: retry == null ? null : 'جرّب تاني',
      onAction: retry,
    );

/// A live query with loading and error states built in.
class Live extends StatelessWidget {
  const Live(this.query, {super.key, required this.builder, this.loading = const LoadingView()});
  final Query<Json> query;
  final Widget Function(BuildContext, List<QDoc>) builder;
  final Widget loading;
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Json>>(
        stream: query.snapshots(),
        builder: (context, s) {
          if (s.hasError) return errorView();
          if (!s.hasData) return loading;
          return builder(context, s.data!.docs);
        },
      );
}

/// A live single document with loading and error states built in.
class LiveDoc extends StatelessWidget {
  const LiveDoc(this.ref, {super.key, required this.builder});
  final DocumentReference<Json> ref;
  final Widget Function(BuildContext, Doc) builder;
  @override
  Widget build(BuildContext context) => StreamBuilder<Doc>(
        stream: ref.snapshots(),
        builder: (context, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(), body: errorView());
          if (!s.hasData) return Scaffold(appBar: AppBar(), body: const LoadingView());
          if (!s.data!.exists) {
            return Scaffold(
                appBar: AppBar(),
                body: const MessageView(icon: Icons.search_off, title: 'الحاجة دي مبقتش موجودة'));
          }
          return builder(context, s.data!);
        },
      );
}

// ── Layout pieces ───────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.sub});
  final String title;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tt(context).titleLarge),
          if (sub != null) Text(sub!, style: tt(context).bodySmall),
        ]),
      );
}

/// Label on top, value below — easier to scan than side-by-side on a small screen.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.label, this.value, {super.key});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 28, color: C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: tt(context).bodySmall),
              Text(value, style: tt(context).titleSmall),
            ]),
          ),
        ]),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color = C.green, this.bg = C.greenBg});
  final String text;
  final IconData? icon;
  final Color color, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 6)],
          Flexible(child: Text(text, style: tt(context).labelSmall?.copyWith(color: color))),
        ]),
      );
}

/// "آخر تحديث للسعر من ساعتين" or, after 48 hours, "سعر قديم".
class Freshness extends StatelessWidget {
  const Freshness(this.priceAt, {super.key});
  final Object? priceAt;
  @override
  Widget build(BuildContext context) {
    final t = timeOf(priceAt);
    return isStale(t, DateTime.now())
        ? Pill('سعر قديم · آخر تحديث ${ago(t)}', icon: Icons.warning_amber, color: C.amber, bg: C.amberBg)
        : Pill('السعر متحدّث ${ago(t)}', icon: Icons.update);
  }
}

class PriceText extends StatelessWidget {
  const PriceText(this.price, {super.key, this.big = false});
  final num price;
  final bool big;
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: fmt(price), style: (big ? tt(context).headlineMedium : tt(context).headlineSmall)),
        TextSpan(text: ' جنيه للطن', style: tt(context).bodyMedium),
      ]));
}

/// Icon with its label underneath (icons are never shown alone).
class LabeledIcon extends StatelessWidget {
  const LabeledIcon({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge', style: const TextStyle(fontSize: 14)),
                child: Icon(icon, size: 30),
              ),
              Text(label, style: tt(context).labelSmall),
            ]),
          ),
        ),
      );
}

/// The two big home actions.
class BigButton extends StatelessWidget {
  const BigButton(
      {super.key, required this.icon, required this.title, required this.sub, required this.color, required this.onTap});
  final IconData icon;
  final String title, sub;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tt(context).headlineSmall?.copyWith(color: Colors.white)),
                  Text(sub, style: tt(context).bodyMedium?.copyWith(color: Colors.white)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ]),
          ),
        ),
      );
}

/// A full-width tappable row with a count and an optional "needs your reply" badge.
class ActionRow extends StatelessWidget {
  const ActionRow(
      {super.key, required this.icon, required this.title, required this.sub, required this.onTap, this.badge = 0});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icon, size: 34, color: C.green),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: tt(context).titleMedium),
                      Text(sub, style: tt(context).bodySmall),
                    ]),
                  ),
                  if (badge > 0)
                    Pill('محتاج ردك ($badge)', color: Colors.white, bg: C.red)
                  else
                    const Icon(Icons.arrow_forward_ios, size: 22, color: C.muted),
                ]),
              ),
            ),
          ),
        ),
      );
}

// ── Step-by-step forms ──────────────────────────────────────────────────────

/// Frame for one step of a form: title, "خطوة 2 من 7", progress bar, one question, big buttons.
class StepFlow extends StatelessWidget {
  const StepFlow({
    super.key,
    required this.title,
    required this.step,
    required this.total,
    required this.child,
    required this.onNext,
    required this.onBack,
    this.nextLabel = 'التالي',
    this.busy = false,
    this.extra,
    this.banner,
  });
  final String title, nextLabel;
  final int step, total;
  final Widget child;
  final VoidCallback onNext, onBack;
  final bool busy;
  final Widget? extra, banner;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(tooltip: 'رجوع', icon: const Icon(Icons.arrow_back), onPressed: onBack),
        ),
        body: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('خطوة $step من $total', style: tt(context).titleSmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: step / total, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            ]),
          ),
          if (banner != null) banner!,
          Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [child])),
        ]),
        bottomNavigationBar: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton(
                onPressed: busy ? null : onNext,
                child: busy
                    ? const SizedBox.square(
                        dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : Text(nextLabel),
              ),
              if (extra != null) ...[const SizedBox(height: 8), extra!],
              if (step > 1) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: busy ? null : onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('رجوع للخطوة اللي فاتت')),
              ],
            ]),
          ),
        ),
      );
}

/// The question asked on a step.
class Ask extends StatelessWidget {
  const Ask(this.title, {super.key, this.hint});
  final String title;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tt(context).headlineSmall),
          if (hint != null) ...[const SizedBox(height: 6), Text(hint!, style: tt(context).bodyMedium?.copyWith(color: C.muted))],
        ]),
      );
}

/// Saves the form on every change and restores it when the user comes back.
mixin DraftForm<T extends StatefulWidget> on State<T> {
  String get draftKey;
  Json defaults();
  Json v = {};
  int step = 1;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    v = defaults();
    Drafts.load(draftKey).then((d) {
      if (d == null || !mounted) return;
      setState(() {
        v = {...v, ...d}..remove('_step');
        step = (d['_step'] ?? 1) as int;
        restored = true;
      });
    });
  }

  void _persist() => Drafts.save(draftKey, {...v, '_step': step});

  void set(String key, Object? value) {
    setState(() => v[key] = value);
    _persist();
  }

  void go(int s) {
    setState(() => step = s);
    _persist();
  }

  void back() => step > 1 ? go(step - 1) : Navigator.pop(context);

  void startOver() {
    Drafts.clear(draftKey);
    setState(() {
      v = defaults();
      step = 1;
      restored = false;
    });
  }

  Widget? get restoredBanner => restored
      ? Container(
          color: C.blueBg,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(children: [
            const Icon(Icons.history, color: C.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('رجّعنالك اللي كنت كاتبه', style: tt(context).labelMedium?.copyWith(color: C.blue))),
            TextButton(onPressed: startOver, child: const Text('ابدأ من الأول')),
          ]),
        )
      : null;
}

// ── Choices ─────────────────────────────────────────────────────────────────

class Opt<T> {
  const Opt(this.value, this.label, {this.sub, this.icon});
  final T value;
  final String label;
  final String? sub;
  final IconData? icon;
}

class OptionTile extends StatelessWidget {
  const OptionTile(
      {super.key, required this.label, required this.selected, required this.onTap, this.sub, this.icon, this.multi = false});
  final String label;
  final String? sub;
  final IconData? icon;
  final bool selected, multi;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? C.greenBg : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: selected ? C.green : C.line, width: selected ? 3 : 1.5),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    if (icon != null) ...[Icon(icon, size: 34, color: C.green), const SizedBox(width: 14)],
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: tt(context).titleMedium),
                        if (sub != null) Text(sub!, style: tt(context).bodySmall),
                      ]),
                    ),
                    Icon(
                      multi
                          ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                          : (selected ? Icons.check_circle : Icons.radio_button_unchecked),
                      size: 32,
                      color: selected ? C.green : C.muted,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class Options<T> extends StatelessWidget {
  const Options({super.key, required this.items, required this.selected, required this.onSelect});
  final List<Opt<T>> items;
  final T? selected;
  final ValueChanged<T> onSelect;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final o in items)
          OptionTile(
              label: o.label, sub: o.sub, icon: o.icon, selected: o.value == selected, onTap: () => onSelect(o.value)),
      ]);
}

/// Several big chips in a wrap (for short values like 46% or 12%).
class ChipPick<T> extends StatelessWidget {
  const ChipPick({super.key, required this.items, required this.selected, required this.onSelect});
  final List<Opt<T>> items;
  final T? selected;
  final ValueChanged<T> onSelect;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final o in items)
          ChoiceChip(
            label: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 32),
                child: Text(o.label, textAlign: TextAlign.center)),
            selected: o.value == selected,
            onSelected: (_) => onSelect(o.value),
          ),
      ]);
}

/// Opens a list of options in a sheet and returns the chosen value.
Future<T?> pickOption<T>(BuildContext context, String title, List<Opt<T>> items, T? selected) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), shrinkWrap: true, children: [
            Text(title, style: tt(c).headlineSmall),
            const SizedBox(height: 12),
            Options<T>(items: items, selected: selected, onSelect: (v) => Navigator.pop(c, v)),
          ]),
        ),
      ),
    );

List<Opt<String>> areaOptions() => [for (final a in areas) Opt(a.$1, a.$1, sub: 'محافظة ${a.$2}')];

/// Delivery day choices + "pick a day from the calendar". Returns millis or null.
class DatePick extends StatelessWidget {
  const DatePick({super.key, required this.selected, required this.onSelect});
  final int? selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final fixed = {for (final (d, _) in deliveryChoices) dayMillis(d)};
    final custom = selected != null && !fixed.contains(selected);
    return Column(children: [
      for (final (d, label) in deliveryChoices)
        OptionTile(
          label: label,
          sub: dateText(DateTime.fromMillisecondsSinceEpoch(dayMillis(d))),
          selected: selected == dayMillis(d),
          onTap: () => onSelect(dayMillis(d)),
        ),
      OptionTile(
        icon: Icons.calendar_month,
        label: custom ? 'يوم ${dayLabel(DateTime.fromMillisecondsSinceEpoch(selected!))}' : 'اختار يوم تاني من النتيجة',
        selected: custom,
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            firstDate: now,
            lastDate: now.add(const Duration(days: 120)),
            initialDate: now.add(const Duration(days: 3)),
            helpText: 'اختار يوم التسليم',
            cancelText: 'إلغاء',
            confirmText: 'تمام',
          );
          if (d != null) onSelect(DateTime(d.year, d.month, d.day).millisecondsSinceEpoch);
        },
      ),
    ]);
  }
}

/// Big number with − / + buttons; tap the number to type it.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.unit,
    this.step = 1,
    this.min = 1,
    this.max = 10000000,
    this.quick = const [],
    this.quickRelative = false,
  });
  final int value, step, min, max;
  final ValueChanged<int> onChanged;
  final String unit;
  final List<int> quick;
  final bool quickRelative; // quick chips add/subtract instead of setting a value

  void _set(int x) => onChanged(x.clamp(min, max));

  Future<void> _type(BuildContext context) async {
    final ctrl = TextEditingController(text: '$value');
    final r = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اكتب الرقم'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          style: tt(c).headlineSmall,
          decoration: InputDecoration(suffixText: unit),
          onSubmitted: (t) => Navigator.pop(c, parseAmount(t)),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, parseAmount(ctrl.text)), child: const Text('تمام')),
        ],
      ),
    );
    if (r != null) _set(r);
  }

  Widget _btn(BuildContext context, IconData icon, String label, int delta) => SizedBox(
        width: 84,
        height: 84,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(84, 84)),
          onPressed: (value + delta < min || value + delta > max) ? null : () => _set(value + delta),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 34),
            Text(label, style: tt(context).labelSmall),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          _btn(context, Icons.add, 'زوّد', step),
          Expanded(
            child: InkWell(
              onTap: () => _type(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  FittedBox(child: Text(fmt(value), style: tt(context).displaySmall)),
                  Text(unit, style: tt(context).titleSmall),
                  Text('اضغط على الرقم لو عايز تكتبه', style: tt(context).bodySmall, textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
          _btn(context, Icons.remove, 'قلّل', -step),
        ]),
        if (quick.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (final q in quick)
              ActionChip(
                label: Text(quickRelative ? (q > 0 ? '+${fmt(q)}' : '−${fmt(-q)}') : fmt(q),
                    textDirection: TextDirection.ltr),
                onPressed: () => _set(quickRelative ? value + q : q),
              ),
          ]),
        ],
      ]);
}

// ── Photos ──────────────────────────────────────────────────────────────────

/// Lets the user take or choose a photo; it is resized and compressed before upload.
Future<String?> addPhoto(BuildContext context) async {
  final source = await pickOption<ImageSource>(context, 'منين الصورة؟', const [
    Opt(ImageSource.camera, 'صوّر بالكاميرا', icon: Icons.photo_camera),
    Opt(ImageSource.gallery, 'اختار من الصور', icon: Icons.photo_library),
  ], null);
  if (source == null) return null;
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 70);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (!context.mounted) return null;
  if (bytes.length > 500 * 1024) {
    showProblem(context, 'الصورة كبيرة قوي. جرّب صورة تانية.');
    return null;
  }
  String? id;
  await attempt(context, () async => id = await savePhoto(bytes));
  return id;
}

/// A photo from the `photos` collection, or a clear placeholder when there is none.
class PhotoBox extends StatelessWidget {
  const PhotoBox(this.id,
      {super.key, this.size = 84, this.icon = Icons.image_outlined, this.label = 'مفيش صورة', this.circle = false});
  final String? id;
  final double size;
  final IconData icon;
  final String label;
  final bool circle;

  Widget _frame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size : 12),
        child: SizedBox.square(dimension: size, child: child),
      );

  Widget _placeholder(BuildContext context) => _frame(Container(
        color: const Color(0xFFE2E8F0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: size * 0.38, color: C.muted),
          if (size >= 80 && !circle) Text(label, style: tt(context).labelSmall?.copyWith(color: C.muted)),
        ]),
      ));

  @override
  Widget build(BuildContext context) {
    if (id == null || id!.isEmpty) return _placeholder(context);
    return FutureBuilder<Uint8List?>(
      future: loadPhoto(id!),
      builder: (context, s) => s.data == null
          ? (s.connectionState == ConnectionState.done
              ? _placeholder(context)
              : _frame(const ColoredBox(color: Color(0xFFE2E8F0))))
          : _frame(Image.memory(s.data!, fit: BoxFit.cover, semanticLabel: 'صورة')),
    );
  }
}

/// App logo: a green tile with a white ear of grain, drawn in code (same design as
/// tool/make_icons.py) so no image has to be downloaded or decoded.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'فيد تك',
        child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22)), Paint()..color = C.green);
    final white = Paint()..color = Colors.white;
    final h = s * 0.66, cx = s / 2, cy = s / 2;
    canvas.drawLine(Offset(cx, cy + h * 0.5), Offset(cx, cy - h * 0.32), white..strokeWidth = h * 0.07);
    for (final dy in [0.22, 0.0, -0.22]) {
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + side * h * 0.13, cy + dy * h - h * 0.05);
        canvas.rotate(side * 0.61); // ~35° away from the stem
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * 0.16, height: h * 0.27), white);
        canvas.restore();
      }
    }
    canvas.drawOval(Rect.fromLTWH(cx - h * 0.08, cy - h * 0.5, h * 0.16, h * 0.27), white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}
