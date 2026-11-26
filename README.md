# FeedTech: two-phone demo

An Arabic (RTL) Flutter + Firebase demo for pitching to feed mills and suppliers.
The story it shows: a supplier posts a price and the factory sees it at once; the factory requests
quotes; the two negotiate and agree a deal. All data is sample data.

## One-time setup (Firebase free Spark plan, no billing)
1. `npm i -g firebase-tools` (if missing), then `firebase login`.
2. In the Firebase console: create a project, then
   - Authentication → Sign-in method → enable **Anonymous**;
   - Firestore → create a database (closest region, e.g. `europe-west1`).
3. `dart pub global activate flutterfire_cli`, then from this folder:
   `flutterfire configure --project=<project-id> --platforms=android,ios,web`
   (this replaces `lib/firebase_options.dart`).
4. `firebase deploy --only firestore:rules --project <project-id>`

## Run the demo
- Two Android phones: `flutter run` on each (or share the APK through Firebase App Distribution).
- iPhone: `flutter build web` then `firebase deploy --only hosting --project <project-id>`, and open the link in Safari.
- Before each pitch, tap **تحميل بيانات تجريبية** once: it refreshes the sample listings for 24 hours.

## Files
- `lib/catalog.dart`: demo businesses (fictional), product catalogue, sample prices, seeding.
- `lib/main.dart`: pick an account → live market prices (cheapest first, product filter).
- `lib/deal_rules.dart`: the deal state machine (`nextStatus`), tested in `test/deal_rules_test.dart`.
- `firestore.rules`: server-side rules. Offers can never be edited, quotes are visible only to their seller and the buyer who asked, and deal status changes mirror `deal_rules.dart`.

## Shortcuts to undo before real users
Each one is marked `shortcut:` in the code: anonymous sign-in (→ phone OTP), the catalogue in code (→ a `products`
collection), filtering on the phone (→ indexed queries), anyone can reload `seeded` listings.
