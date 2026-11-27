// Choices: option tiles, chips, pickers, date choice and the number stepper.

import 'package:flutter/material.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/shared/constants/app_constants.dart';
import 'package:feedtech/shared/constants/app_theme.dart';
import 'package:feedtech/shared/utils/formatters.dart';

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
