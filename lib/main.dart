import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'catalog.dart';
import 'firebase_options.dart';
import 'post_offer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // shortcut: anonymous sign-in for the demo; switch to phone OTP (Firebase test numbers) before pilots.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(const FeedTechApp());
}

class FeedTechApp extends StatelessWidget {
  const FeedTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeedTech',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'), // Arabic locale = right-to-left everywhere
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        textTheme: GoogleFonts.cairoTextTheme(),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const PickBusinessScreen(),
    );
  }
}

class PickBusinessScreen extends StatelessWidget {
  const PickBusinessScreen({super.key});

  Future<void> _pick(BuildContext context, Business b) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.doc('users/$uid').set({'businessId': b.id});
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketScreen(me: b)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FeedTech · اختار حسابك')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final b in demoBusinesses)
            Card(
              child: ListTile(
                leading: Icon(b.isSeller ? Icons.inventory_2 : Icons.factory),
                title: Text(b.name),
                subtitle: Text('${b.isSeller ? 'مورد خامات' : 'مصنع أعلاف'} · ${b.governorate}'),
                onTap: () => _pick(context, b),
              ),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('تحميل بيانات تجريبية'),
            onPressed: () async {
              await seedDemoData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم تحميل العروض التجريبية')));
            },
          ),
        ],
      ),
    );
  }
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, required this.me});
  final Business me;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String? _productId; // null = all products

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('أسعار السوق · ${widget.me.name}')),
      floatingActionButton: widget.me.isSeller
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('نشر عرض'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PostOfferScreen(seller: widget.me)),
              ),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final (id, name) in [(null, 'الكل'), for (final p in demoProducts) (p.id, p.name)])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _productId == id,
                      onSelected: (_) => setState(() => _productId = id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Live: a listing posted on the other phone appears here at once. Cheapest first.
              stream: FirebaseFirestore.instance.collection('listings').orderBy('price').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final now = DateTime.now();
                // shortcut: filtering on the phone is fine for demo volumes; use indexed queries for real data.
                final docs = snap.data!.docs.where((d) {
                  final x = d.data();
                  return x['status'] == 'active' &&
                      (x['expiresAt'] as Timestamp).toDate().isAfter(now) &&
                      (_productId == null || x['productId'] == _productId);
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('مفيش عروض النهارده · اطلب عرض سعر'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88), // room for the post button
                  itemCount: docs.length,
                  itemBuilder: (_, i) => ListingCard(data: docs[i].data()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.data});
  final Map<String, dynamic> data;
  static final _n = NumberFormat.decimalPattern('en');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hoursLeft = (data['expiresAt'] as Timestamp).toDate().difference(DateTime.now()).inHours;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${data['productName']} · ${data['spec']}', style: t.titleMedium)),
              Text('${_n.format(data['price'])} ج/طن',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.verified, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text('${data['sellerName']}'),
            ]),
            const SizedBox(height: 4),
            Text(
              '${_n.format(data['qty'])} طن متاح · أقل كمية ${data['minQty']} طن · ${data['governorate']}',
              style: t.bodySmall,
            ),
            Text('${data['payment']} · ${data['delivery']} · ينتهي بعد $hoursLeft ساعة',
                style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
