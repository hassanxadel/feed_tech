import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feedtech/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 27, 10);
  const defs = [
    SpecDef('protein', 'البروتين', 'min', '%', [44, 46, 48]),
    SpecDef('moisture', 'الرطوبة', 'max', '%', [11, 12, 13]),
    SpecDef('origin', 'المنشأ', 'choice', '', ['محلي', 'مستورد']),
  ];

  Map<String, dynamic> ad({
    int price = 25000,
    int qty = 200,
    int minOrder = 10,
    int days = 1,
    Map specs = const {'protein': 46, 'moisture': 12, 'origin': 'محلي'},
    Duration age = const Duration(hours: 3),
    List<String> payments = const ['cash', 'transfer'],
    String area = 'السادات',
  }) =>
      {
        'materialId': 'soybean_meal',
        'active': true,
        'price': price,
        'qty': qty,
        'minOrder': minOrder,
        'deliveryDays': days,
        'specs': specs,
        'priceAt': Timestamp.fromDate(now.subtract(age)),
        'payments': payments,
        'area': area,
      };

  final want = Want(
    materialId: 'soybean_meal',
    qty: 70,
    budget: 25000,
    specs: const {'protein': 46, 'moisture': null, 'origin': null},
    deliveryDate: DateTime(2026, 11, 28),
    payment: 'transfer',
    area: 'السادات',
  );

  test('specs: min, max, choice and "any"', () {
    expect(specsMeet(defs, {'protein': 48, 'moisture': 11, 'origin': 'محلي'}, {'protein': 46, 'moisture': 12}), isTrue);
    expect(specsMeet(defs, {'protein': 44}, {'protein': 46}), isFalse);
    expect(specsMeet(defs, {'moisture': 13}, {'moisture': 12}), isFalse);
    expect(specsMeet(defs, {'origin': 'مستورد'}, {'origin': 'محلي'}), isFalse);
    expect(specsMeet(defs, {}, {'protein': null}), isTrue);
  });

  test('full matches rank cheaper and fresher first, and exclude what does not fit', () {
    final r = matchAds({
      'cheap': ad(price: 24500),
      'budget': ad(),
      'staleCheap': ad(price: 24400, age: const Duration(days: 4)),
      'lowProtein': ad(price: 23000, specs: {'protein': 44, 'moisture': 12, 'origin': 'محلي'}),
      'tooLittle': ad(qty: 40),
      'tooLate': ad(days: 7),
      'tooDear': ad(price: 28000),
    }.entries, want, defs, now);
    expect(r.map((m) => m.id), ['cheap', 'budget', 'staleCheap']);
    expect(r.first.overBudget, -500);
    expect(r.every((m) => m.gaps.isEmpty), isTrue);
  });

  test('no full match → closest ads with what is missing', () {
    final r = matchAds({'tooLittle': ad(qty: 40), 'other': {...ad(), 'materialId': 'yellow_corn'}}.entries, want, defs, now);
    expect(r.single.id, 'tooLittle');
    expect(r.single.gaps, ['متاح 40 طن بس']);
  });

  test('price freshness, stats and calendar days', () {
    expect(isStale(now.subtract(const Duration(hours: 47)), now), isFalse);
    expect(isStale(now.subtract(const Duration(hours: 49)), now), isTrue);
    final s = statsOf([24000, 25000, 25500])!;
    expect([s.avg, s.min, s.max, s.count], [24830, 24000, 25500, 3]);
    expect(statsOf([]), isNull);
    expect(daysUntil(DateTime(2026, 11, 28, 1), now), 1);
    expect(daysUntil(DateTime(2026, 11, 20), now), 0);
    expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('order steps', () {
    expect(orderMoves('new', isSeller: true), ['confirmed', 'cancelled']);
    expect(orderMoves('new', isSeller: false), ['cancelled']);
    expect(orderMoves('confirmed', isSeller: false), ['delivered', 'cancelled']);
    expect(orderMoves('delivered', isSeller: true), isEmpty);
  });

  test('reads numbers from any keyboard', () {
    expect(parseAmount('24,900'), 24900);
    expect(parseAmount('٢٤٬٩٠٠'), 24900);
    expect(parseAmount('۲۴۹۰۰'), 24900);
    expect(parseAmount('24.5'), isNull);
    expect(parseAmount('طن'), isNull);
    expect(westernDigits('٠١٠٠٠٠٠٠٠٠١'), '01000000001');
  });
}
