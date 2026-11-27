import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:feedtech/firebase_options.dart';
import 'package:feedtech/presentation/widgets/auth_gate.dart';
import 'package:feedtech/shared/constants/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FeedTechApp());
}

class FeedTechApp extends StatelessWidget {
  const FeedTechApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'فيد تك',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'), // Arabic, right-to-left everywhere (dialogs and date picker too)
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}
