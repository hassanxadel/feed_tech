/// The deal state machine. The app uses it to decide which buttons to show;
/// firestore.rules enforces the same table on the server, so keep the two in sync.
enum DealStatus { negotiating, agreed, declined, cancelled }

enum DealAction { counter, accept, decline, cancel }

/// Returns the status after [action], or null when the action is not allowed.
/// [actorMadeLastOffer] is true when the person acting sent the latest price.
DealStatus? nextStatus(DealStatus current, DealAction action, {required bool actorMadeLastOffer}) {
  if (current != DealStatus.negotiating) return null; // agreed, declined and cancelled are final
  return switch (action) {
    // Only the side that received the latest price can answer it.
    DealAction.accept => actorMadeLastOffer ? null : DealStatus.agreed,
    DealAction.counter => actorMadeLastOffer ? null : DealStatus.negotiating,
    DealAction.decline => actorMadeLastOffer ? null : DealStatus.declined,
    // Either side may walk away while talks are open.
    DealAction.cancel => DealStatus.cancelled,
  };
}
