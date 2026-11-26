/// The deal state machine. The app uses it to decide which buttons to show;
/// firestore.rules enforces the same table on the server, so keep the two in sync.
enum DealStatus { negotiating, agreed, declined, cancelled }

enum DealAction { counter, accept, decline, cancel }

/// Returns the status after [action], or null when the action is not allowed.
/// [actorMadeLastOffer] is true when the person acting sent the latest price.
DealStatus? nextStatus(DealStatus current, DealAction action, {required bool actorMadeLastOffer}) {
  // TODO(you): implement the rules (5-10 lines). Run `flutter test` to check.
  throw UnimplementedError();
}
