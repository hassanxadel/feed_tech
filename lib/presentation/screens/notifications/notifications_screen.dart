import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/models/me.dart';
import 'package:feedtech/presentation/screens/ads/ads_screens.dart';
import 'package:feedtech/presentation/screens/deals/deals_screens.dart';
import 'package:feedtech/presentation/screens/home/home_screens.dart';
import 'package:feedtech/presentation/screens/requests/requests_screens.dart';
import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/services/firebase_service.dart';
import 'package:feedtech/services/queries.dart';
import 'package:feedtech/shared/constants/app_theme.dart';
import 'package:feedtech/shared/utils/formatters.dart';

/// Turns on phone (browser) notifications. Returns null on success, or what the user should do.
/// Delivery needs the `functions/` Cloud Function, which needs the Blaze plan.
Future<String?> enablePush() async {
  final m = FirebaseMessaging.instance;
  if (!await m.isSupported()) {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'على الآيفون: اضغط زرار المشاركة تحت، واختار "إضافة إلى الشاشة الرئيسية". افتح التطبيق من الأيقونة الجديدة وارجع هنا فعّل التنبيهات.'
        : 'المتصفح ده مش بيدعم تنبيهات الموبايل. التنبيهات هتفضل تظهرلك هنا جوه التطبيق.';
  }
  final s = await m.requestPermission();
  if (s.authorizationStatus != AuthorizationStatus.authorized) {
    return 'لازم توافق على التنبيهات لما المتصفح يسألك. لو رفضتها قبل كده، فعّلها من إعدادات المتصفح.';
  }
  final token = await m.getToken();
  if (token == null) return 'مقدرناش نفعّل التنبيهات دلوقتي. جرّب تاني بعدين.';
  await db.doc('users/$myUid').update({'fcmTokens': FieldValue.arrayUnion([token])});
  return null;
}

const _icons = {
  'request': Icons.campaign_outlined,
  'offer': Icons.local_offer_outlined,
  'counter': Icons.price_change_outlined,
  'accept': Icons.handshake_outlined,
  'decline': Icons.block,
  'cancel': Icons.cancel_outlined,
  'order': Icons.receipt_long,
  'reminder': Icons.alarm,
};

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _open(BuildContext context, QDoc n) {
    final d = n.data();
    if (d['read'] != true) n.reference.update({'read': true});
    final target = (d['target'] ?? '') as String;
    final screen = switch (d['kind']) {
      'request' => RequestScreen(id: target),
      'negotiation' => NegotiationScreen(id: target),
      'order' => OrderScreen(id: target),
      'myAds' => const MyAdsScreen(),
      _ => null,
    };
    if (screen != null) open(context, screen);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التنبيهات')),
        body: Live(myNotifications, builder: (context, docs) {
          final unread = docs.where((d) => d.data()['read'] != true).toList();
          // shortcut: loads all of a user's notifications; add paging when lists grow past a few hundred.
          final list = newest(docs, 'at');
          return ListView(padding: const EdgeInsets.all(16), children: [
            if ((Me.data['fcmTokens'] as List?)?.isNotEmpty != true) const _PushCard(),
            if (unread.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => attempt(context, () async {
                    final b = db.batch();
                    for (final d in unread) {
                      b.update(d.reference, {'read': true});
                    }
                    await b.commit();
                  }),
                  icon: const Icon(Icons.done_all),
                  label: const Text('علّم الكل مقروء'),
                ),
              ),
            if (list.isEmpty)
              const MessageView(
                  icon: Icons.notifications_none, title: 'مفيش تنبيهات لسه', text: 'هنبلّغك هنا بالعروض والطلبات الجديدة')
            else
              for (final n in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: n.data()['read'] == true ? Colors.white : C.greenBg,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Icon(_icons[(n.data()['type'] as String).replaceFirst(RegExp(r'^order-.*'), 'order')] ?? Icons.notifications,
                          size: 34, color: C.green),
                      title: Text(n.data()['text'] as String,
                          style: n.data()['read'] == true ? tt(context).bodyLarge : tt(context).titleMedium),
                      subtitle: Text(ago(timeOf(n.data()['at']))),
                      onTap: () => _open(context, n),
                    ),
                  ),
                ),
          ]);
        }),
      );
}

class _PushCard extends StatefulWidget {
  const _PushCard();
  @override
  State<_PushCard> createState() => _PushCardState();
}

class _PushCardState extends State<_PushCard> {
  String? _message;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          color: C.blueBg,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('عايز التنبيهات توصلك على الموبايل حتى لو التطبيق مقفول؟', style: tt(context).titleSmall),
              const SizedBox(height: 10),
              if (_message != null) ...[Text(_message!, style: tt(context).bodyMedium), const SizedBox(height: 10)],
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        String? m;
                        try {
                          m = await enablePush();
                        } catch (_) {
                          m = 'مقدرناش نفعّل التنبيهات دلوقتي. جرّب تاني بعدين.';
                        }
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _message = m;
                        });
                        if (m == null) showDone(this.context, 'فعّلنا التنبيهات ✓');
                      },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('فعّل التنبيهات'),
              ),
            ]),
          ),
        ),
      );
}
