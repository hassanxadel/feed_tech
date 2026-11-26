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

## The pitch story (tested end to end on the web build)
1. Phone A picks **مصنع النور** (feed mill), phone B picks **الوادي** or **الدلتا** (suppliers).
2. Market prices: the mill taps a listing, offers a lower price → a deal opens; the supplier's **الصفقات** tab gets a badge.
3. The supplier sends a counter-offer (**سعر جديد**); the mill accepts → **تم الاتفاق** on both phones.
4. **طلباتي** → **اطلب عرض سعر**: the mill asks for 50 t of soybean meal; each supplier taps **قدّم سعر**;
   the mill sees the quotes side by side, cheapest first, and accepts one.
5. A supplier taps **نشر عرض** on the market tab: the new price appears on the mill's phone at once.

Screens: account picker → home (3 tabs: أسعار السوق, طلباتي / طلبات المصانع, الصفقات) → deal; plus the post-offer form.
Two browser tabs on one computer share one sign-in, so test the two sides on two devices (or switch accounts).

## Files
- `lib/catalog.dart`: demo businesses (fictional), product catalogue, sample prices, seeding.
- `lib/main.dart`: Firebase start-up and the account picker.
- `lib/home.dart`: the three tabs (market prices, requests for quotation, deals).
- `lib/deal.dart`: the deal screen (negotiation history, accept / counter / decline / cancel) and its dialogs.
- `lib/post_offer.dart`: the supplier's post-offer form and `parseAmount` (reads Arabic-Indic digits).
- `lib/deal_rules.dart`: the deal state machine (`nextStatus`), tested in `test/deal_rules_test.dart`.
- `firestore.rules`: server-side rules. Offers can never be edited, a deal (an order or a quote) is visible only
  to its buyer and seller, and status changes mirror `deal_rules.dart`.

## Shortcuts to undo before real users
Each one is marked `shortcut:` in the code: anonymous sign-in (→ phone OTP), the catalogue in code (→ a `products`
collection), filtering on the phone (→ indexed queries), anyone can reload `seeded` listings.
