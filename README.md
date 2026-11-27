# فيد تك (FeedTech): Egyptian feed-materials marketplace

A mobile-first Flutter **web** app (Arabic, right-to-left) where feed factories and raw-material
suppliers trade soybean meal, yellow corn, soybeans and bran. Built for older users who rarely use
smartphones: 18px+ text, 56–60px buttons, one question per screen, pickers and steppers instead of typing.

Live: https://feedtech-fabe2.web.app

## Test accounts (sign-in is phone + 6-digit PIN)
| Role | Phone | PIN | Company |
|------|-------|-----|---------|
| Buyer (factory) | 01000000001 | 123456 | مصنع النور للأعلاف |
| Seller (supplier) | 01000000002 | 123456 | الدلتا لكسب الصويا |

Each account opens with things to do: offers to compare and accept, a counter-offer to answer,
an order to confirm, a stale price to update.

## What the app does
- **Home**: two big buttons (اطلب بضاعة / اعرض بضاعتك), "waiting for your reply" cards, today's average
  price per material with the change from yesterday (tap for a 30-day chart, today's low/high), "your work"
  with reply badges, and a short "what we do" list.
- **Request goods** (8 short steps, saved as a draft on every tap): sellers of that material are notified,
  and matching sellers are shown right away. Offers on a request are compared cheapest first, with the
  difference from the budget, and can be accepted, countered or declined in place.
- **Show your goods** (8 steps): one-tap "price unchanged" or a quick price/quantity update from إعلاناتي.
  Every update is saved in `priceHistory`. A price older than 48 hours shows "سعر قديم", drops to the end
  of results and leaves the daily average. Sellers get a daily in-app reminder.
- **Market**: material chips, sort (cheapest / nearest / largest quantity), filter (max price, place, min quantity).
- **Negotiation**: every offer/counter/accept/decline is a new step; nothing is overwritten. After
  agreement the buyer completes the order (payment, day, place). Orders go new → confirmed → delivered (or
  cancelled); each side's phone and a call button appear only after the seller confirms.
- **Profile**: company info, logo, years, about, materials, product photos (compressed), lists, logout.
- **Notifications**: stored in Firestore; optional phone push (needs the Blaze plan, see below).

### Smart matching rules (`lib/domain/market_rules.dart`, tested in `test/market_rules_test.dart`)
A seller ad is a full match when: same material; specs meet the request (protein at least the minimum,
moisture at most the maximum, origin/type equal; "مش فارقة" = any); enough quantity; the buyer reaches the
seller's minimum order; the seller can deliver by the requested day; price at most 10% above the budget.
Ranking: 100 points, −4 per % above budget, +1 per % below it (up to +10), −20 for a stale price,
−10 if the seller doesn't take the buyer's payment method, +5 for the same area (transport).
If nothing fully matches, the 5 closest ads are shown with what's missing ("متاح 40 طن بس").

## Code layout (`lib/`)
```
main.dart, firebase_options.dart
domain/        pure business rules, no UI or network: market_rules.dart, deal_rules.dart (unit-tested)
models/        commodity.dart (materials catalogue), me.dart (signed-in business)
services/      Firestore reads and writes: queries, market (requests/ads), deals (negotiations/orders),
               notifications, drafts, photos, firebase_service (db, myUid, Json types)
shared/        constants/ (app_theme, app_constants: places, payments, roles), utils/formatters.dart
presentation/  widgets/ (shared UI, auth_gate) and screens/<feature>/ (auth, home, market, ads,
               requests, deals, profile, notifications)
```
`domain/`, `models/`, `services/` and `shared/` never import from `presentation/`.

## Data model (Firestore)
`materials` (catalogue + spec definitions) · `users/{uid}` (+ `private/contact` phone) · `photos` ·
`ads` · `priceHistory` · `dailyPrices/{material}_{day}` · `requests` · `negotiations` (+ `steps`) ·
`orders` (+ `contacts`, readable only after confirmation) · `notifications`.
Security: `firestore.rules` (only the two parties see a negotiation or order; state changes mirror
`lib/domain/deal_rules.dart` and `orderMoves()`).

## Commands
```
flutter test
flutter build web --release --pwa-strategy=none
firebase deploy --only hosting,firestore:rules --project feedtech-fabe2
```
`--pwa-strategy=none` matters: Flutter's own service worker delayed start-up by ~6 s and kept serving old
builds after updates. The app still installs to the home screen (manifest + icons).

**Seed / reset the demo data** (replaces all app data; both test accounts must exist):
```
cd tool && npm install && node seed.mjs
```
It signs in anonymously, deploys a temporary rule that lets only that sign-in write, writes 30 days of
data (18 sellers, 10 factories, 26 ads, ~600 price updates, requests, negotiations, orders, notifications),
and always redeploys `firestore.rules`. App icons: `python tool/make_icons.py`.

## Free-plan limits and how to lift them (Blaze plan)
- **Sign-in**: phone + PIN without SMS (Firebase SMS needs Blaze). Switch to SMS codes after upgrading.
- **Photos**: stored compressed in Firestore (`photos`); move to Firebase Storage after upgrading.
- **Phone push**: `functions/index.js` sends a push for each notification. Deploy with
  `cd functions && npm install && cd .. && firebase deploy --only functions --project feedtech-fabe2`.
- **Daily averages** are recomputed by the app on open; a scheduled Cloud Function would be stricter.
