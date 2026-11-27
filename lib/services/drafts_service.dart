// Drafts: nothing the user typed is lost if they leave a form.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feedtech/services/firebase_service.dart';

/// Best effort: a storage problem must never break a form, so failures are only logged.
class Drafts {
  static Future<Json?> load(String key) async {
    try {
      final s = (await SharedPreferences.getInstance()).getString('draft:$key');
      return s == null ? null : jsonDecode(s) as Json;
    } catch (e) {
      debugPrint('draft load failed: $e');
      return null;
    }
  }

  static Future<void> save(String key, Json v) async {
    try {
      await (await SharedPreferences.getInstance()).setString('draft:$key', jsonEncode(v));
    } catch (e) {
      debugPrint('draft save failed: $e');
    }
  }

  static Future<void> clear(String key) async {
    try {
      await (await SharedPreferences.getInstance()).remove('draft:$key');
    } catch (e) {
      debugPrint('draft clear failed: $e');
    }
  }
}
