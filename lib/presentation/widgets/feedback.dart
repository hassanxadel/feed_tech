// Messages, confirmations, loading/error states and live Firestore builders.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/shared/constants/app_theme.dart';

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
