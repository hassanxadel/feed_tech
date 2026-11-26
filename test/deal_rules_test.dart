import 'package:feedtech/deal_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Only the cases with one right answer. Add tests for your own policy choices.
void main() {
  test('nobody accepts their own offer', () {
    expect(nextStatus(DealStatus.negotiating, DealAction.accept, actorMadeLastOffer: true), isNull);
  });

  test('the other side can accept', () {
    expect(nextStatus(DealStatus.negotiating, DealAction.accept, actorMadeLastOffer: false),
        DealStatus.agreed);
  });

  test('a counter-offer keeps the deal open', () {
    expect(nextStatus(DealStatus.negotiating, DealAction.counter, actorMadeLastOffer: false),
        DealStatus.negotiating);
  });

  test('a declined deal cannot be accepted', () {
    expect(nextStatus(DealStatus.declined, DealAction.accept, actorMadeLastOffer: false), isNull);
  });
}
