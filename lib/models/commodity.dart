// The materials catalogue (the `materials` collection) and how specs are written out.

import 'package:flutter/material.dart';

import 'package:feedtech/domain/market_rules.dart';
import 'package:feedtech/services/firebase_service.dart';

class Commodity {
  Commodity(this.id, Json m)
      : name = m['name'] as String,
        icon = (m['icon'] ?? '') as String,
        specs = [for (final s in (m['specs'] ?? const []) as List) SpecDef.fromMap(s as Map)];
  final String id, name, icon;
  final List<SpecDef> specs;
}

class Catalog {
  static List<Commodity> all = [];
  static Future<void> load() async {
    final q = await db.collection('materials').orderBy('order').get();
    all = [for (final d in q.docs) Commodity(d.id, d.data())];
  }

  static Commodity byId(String id) => all.firstWhere((c) => c.id == id, orElse: () => Commodity(id, {'name': id}));
}

IconData commodityIcon(String key) => switch (key) {
      'eco' => Icons.eco,
      'grain' => Icons.grain,
      'grass' => Icons.grass,
      'bran' => Icons.scatter_plot,
      _ => Icons.inventory_2,
    };

/// "بروتين 46% · رطوبة 12% · برازيلي". For a request, limits read "أو أكتر" / "أو أقل".
String specText(String materialId, Map? specs, {bool request = false}) {
  final parts = <String>[];
  for (final d in Catalog.byId(materialId).specs) {
    final v = specs?[d.key];
    if (v == null) continue;
    parts.add(switch (d.kind) {
      'min' => '${d.label} ${d.show(v)}${request ? ' أو أكتر' : ''}',
      'max' => '${d.label} ${d.show(v)}${request ? ' أو أقل' : ''}',
      _ => '$v',
    });
  }
  return parts.isEmpty ? (request ? 'أي مواصفات' : '') : parts.join(' · ');
}
