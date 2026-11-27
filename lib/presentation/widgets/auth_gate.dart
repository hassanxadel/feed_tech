import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:feedtech/models/commodity.dart';
import 'package:feedtech/models/me.dart';
import 'package:feedtech/presentation/screens/auth/auth_screens.dart';
import 'package:feedtech/presentation/screens/home/home_screens.dart';
import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/services/firebase_service.dart';

/// Signed out → phone sign-in. Signed in → profile (sign-up if new) → home. Users stay signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) return const Scaffold(body: LoadingView());
          final user = s.data;
          if (user == null) return const LoginScreen();
          if (user.isAnonymous) {
            // A sign-in left over from the old demo: start again with a phone number.
            FirebaseAuth.instance.signOut();
            return const Scaffold(body: LoadingView());
          }
          return ProfileGate(key: ValueKey(user.uid), uid: user.uid);
        },
      );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.uid});
  final String uid;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<void> _catalog = Catalog.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _catalog,
        builder: (context, c) {
          if (c.hasError) {
            return Scaffold(body: errorView(() => setState(() => _catalog = Catalog.load())));
          }
          if (c.connectionState != ConnectionState.done) return const Scaffold(body: LoadingView());
          return StreamBuilder<Doc>(
            stream: db.doc('users/${widget.uid}').snapshots(),
            builder: (context, s) {
              if (s.hasError) return Scaffold(body: errorView());
              if (!s.hasData) return const Scaffold(body: LoadingView());
              if (!s.data!.exists) return const SignUpScreen();
              Me.data = s.data!.data()!;
              return HomeScreen(profile: Me.data);
            },
          );
        },
      );
}
