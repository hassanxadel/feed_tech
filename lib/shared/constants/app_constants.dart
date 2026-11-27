// Places, payment methods, roles and delivery choices.

import 'package:flutter/material.dart';

/// Industrial areas and cities (with their governorate) used for company location and delivery place.
const areas = <(String, String)>[
  ('العاشر من رمضان', 'الشرقية'),
  ('السادات', 'المنوفية'),
  ('العبور', 'القليوبية'),
  ('6 أكتوبر', 'الجيزة'),
  ('برج العرب', 'الإسكندرية'),
  ('بدر', 'القاهرة'),
  ('القاهرة', 'القاهرة'),
  ('الإسكندرية', 'الإسكندرية'),
  ('الجيزة', 'الجيزة'),
  ('قويسنا', 'المنوفية'),
  ('بنها', 'القليوبية'),
  ('الزقازيق', 'الشرقية'),
  ('المنصورة', 'الدقهلية'),
  ('طنطا', 'الغربية'),
  ('دمنهور', 'البحيرة'),
  ('الإسماعيلية', 'الإسماعيلية'),
  ('الفيوم', 'الفيوم'),
  ('بني سويف', 'بني سويف'),
  ('المنيا', 'المنيا'),
  ('أسيوط', 'أسيوط'),
  ('سوهاج', 'سوهاج'),
];

String governorateOf(String area) => areas.where((a) => a.$1 == area).firstOrNull?.$2 ?? '';

String areaLabel(String area) {
  final g = governorateOf(area);
  return g.isEmpty || g == area ? area : '$area (محافظة $g)';
}

const payments = {'cash': 'كاش', 'transfer': 'تحويل بنكي', 'deferred': 'آجل'};
const paymentIcons = {'cash': Icons.payments_outlined, 'transfer': Icons.account_balance, 'deferred': Icons.event_note};
const roles = {'buy': 'بنشتري خامات', 'sell': 'بنبيع خامات', 'both': 'بنشتري وبنبيع'};

/// Delivery choices shown as big buttons (days from today).
const deliveryChoices = <(int, String)>[
  (0, 'النهارده'),
  (1, 'بكرة'),
  (2, 'بعد يومين'),
  (7, 'خلال أسبوع'),
  (14, 'خلال أسبوعين'),
];
