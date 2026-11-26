import 'package:feedtech/post_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads Western, Arabic-Indic and Persian digits with separators', () {
    expect(parseAmount('24900'), 24900);
    expect(parseAmount('24,900'), 24900);
    expect(parseAmount('٢٤٩٠٠'), 24900);
    expect(parseAmount('٢٤٬٩٠٠'), 24900);
    expect(parseAmount('۲۴۹۰۰'), 24900);
    expect(parseAmount(' 50 '), 50);
  });

  test('rejects anything that is not a whole number', () {
    expect(parseAmount(''), isNull);
    expect(parseAmount('24.5'), isNull);
    expect(parseAmount('-5'), isNull);
    expect(parseAmount('طن'), isNull);
  });
}
