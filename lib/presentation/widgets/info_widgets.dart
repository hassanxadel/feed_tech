// Layout pieces: titles, info rows, prices, freshness, big buttons, action rows.

import 'package:flutter/material.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/shared/constants/app_theme.dart';
import 'package:feedtech/shared/utils/formatters.dart';

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
