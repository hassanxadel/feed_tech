// Arabic formatting (Western digits, as traders write prices) and day helpers.

import 'package:intl/intl.dart';

import 'package:feedtech/domain/market_rules.dart';

final _n = NumberFormat.decimalPattern('en');
String fmt(num v) => _n.format(v);
String perTon(num v) => '${fmt(v)} جنيه للطن';
String tons(num v) => '${fmt(v)} طن';

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String dateText(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "النهارده", "بكرة", or "الخميس 4 ديسمبر".
String dayLabel(DateTime d) {
  final days = daysUntil(d, DateTime.now());
  final sameDay = dayKey(d) == dayKey(DateTime.now());
  if (sameDay) return 'النهارده';
  if (days == 1) return 'بكرة';
  return '${_weekdays[d.weekday - 1]} ${dateText(d)}';
}

/// "دلوقتي", "من 5 دقايق", "من ساعتين", "امبارح", "من 3 أيام".
String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'دلوقتي';
  if (m < 60) return m == 1 ? 'من دقيقة' : (m == 2 ? 'من دقيقتين' : (m <= 10 ? 'من $m دقايق' : 'من $m دقيقة'));
  final h = m ~/ 60;
  if (h < 24) return h == 1 ? 'من ساعة' : (h == 2 ? 'من ساعتين' : (h <= 10 ? 'من $h ساعات' : 'من $h ساعة'));
  final d = h ~/ 24;
  if (d == 1) return 'امبارح';
  if (d == 2) return 'من يومين';
  return d <= 10 ? 'من $d أيام' : 'يوم ${dateText(t)}';
}

/// "+1,000 جنيه عن ميزانيتك" / "أقل من ميزانيتك بـ 500 جنيه" / "نفس ميزانيتك".
String budgetDiff(int over) => over > 0
    ? '+${fmt(over)} جنيه عن ميزانيتك'
    : (over < 0 ? 'أقل من ميزانيتك بـ ${fmt(-over)} جنيه' : 'نفس ميزانيتك بالظبط');

int dayMillis(int daysFromToday) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + daysFromToday).millisecondsSinceEpoch;
}
