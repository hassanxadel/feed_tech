import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'catalog.dart';
import 'firebase_options.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // shortcut: anonymous sign-in for the demo; switch to phone OTP (Firebase test numbers) before pilots.
  Object? authError;
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      authError = e; // shown on screen instead of a blank page
    }
  }
  runApp(authError == null
      ? const FeedTechApp()
      : MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Sign-in failed. Enable Anonymous sign-in in Firebase Authentication.\n\n$authError',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ));
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
    // The rules read this to know which business this phone acts for.
    await FirebaseFirestore.instance.doc('users/$uid').set({'businessId': b.id});
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HomeScreen(me: b)));
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
              final messenger = ScaffoldMessenger.of(context);
              try {
                await seedDemoData();
                messenger.showSnackBar(const SnackBar(content: Text('تم تحميل العروض التجريبية')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('ما اتحملتش البيانات ($e)')));
              }
            },
          ),
        ],
      ),
    );
  }
}
