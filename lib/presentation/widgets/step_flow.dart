// Step-by-step forms with progress, back, and saved drafts.

import 'package:flutter/material.dart';

import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/services/drafts_service.dart';
import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/shared/constants/app_theme.dart';

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
