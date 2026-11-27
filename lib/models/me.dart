// The signed-in business's profile.

import 'package:firebase_auth/firebase_auth.dart';

import 'package:feedtech/services/firebase_service.dart';

/// The signed-in business's profile, kept current by the app shell.
class Me {
  static Json data = {};
  static String get company => (data['company'] ?? '') as String;
  static String get name => (data['name'] ?? '') as String;
  static String get area => (data['area'] ?? 'السادات') as String;
  static String get role => (data['role'] ?? 'both') as String;
  static bool get sells => role != 'buy';
  static bool get buys => role != 'sell';
  static List<String> get materials => List<String>.from((data['materials'] ?? const []) as List);
  /// "+201000000001", from the hidden login name "201000000001@phone.feedtech.app".
  static String get phone {
    final u = FirebaseAuth.instance.currentUser;
    final login = u?.email ?? '';
    return u?.phoneNumber ?? (login.contains('@') ? '+${login.split('@').first}' : '');
  }
}
