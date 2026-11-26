import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _n = NumberFormat.decimalPattern('en');

/// 24900 → "24,900" (Western digits, as traders write prices on Facebook).
String fmt(num v) => _n.format(v);

Business businessById(String id) => demoBusinesses.firstWhere((b) => b.id == id);

class Business {
  const Business(this.id, this.name, this.governorate, {required this.isSeller});
  final String id, name, governorate;
  final bool isSeller;
}

class Product {
  const Product(this.id, this.name, this.specs);
  final String id, name;
  final List<String> specs;
}

// Fictional accounts: never put real company names in pitch data.
const demoBusinesses = [
  Business('mill_nour', 'مصنع النور للأعلاف', 'مدينة السادات', isSeller: false),
  Business('delta_soy', 'الدلتا لكسب الصويا', 'العاشر من رمضان', isSeller: true),
  Business('wadi_grain', 'الوادي لتجارة الحبوب', 'العبور', isSeller: true),
];

// shortcut: catalogue lives in code for the demo; move it to a `products` collection before pilots.
const demoProducts = [
  Product('yellow_corn', 'ذرة صفراء', ['برازيلي', 'أرجنتيني', 'أوكراني', 'أمريكي']),
  Product('soybean_meal', 'كسب صويا', ['بروتين 44%', 'بروتين 46%', 'بروتين 48%']),
  Product('full_fat_soy', 'صويا هاي فات', ['محلي']),
  Product('soy_oil', 'زيت صويا خام', ['محلي', 'مستورد']),
  Product('wheat_bran', 'ردة (نخالة قمح)', ['خشنة', 'ناعمة']),
  Product('soy_hulls', 'قشر صويا', ['محلي']),
  Product('corn_gluten', 'جلوتين ذرة', ['بروتين 60%']),
  Product('ddgs', 'DDGS', ['مستورد']),
];

const paymentOptions = ['كاش', 'تحويل بنكي', 'آجل 30 يوم'];
const deliveryOptions = ['تسليم أرض المصنع', 'استلام من المصنع', 'استلام من المخزن'];

/// One listing document, used by the post-offer form and the sample data.
/// Names are copied in so the price list loads with one query (Firestore has no joins).
Map<String, dynamic> listingDoc({
  required Business seller,
  required Product product,
  required String spec,
  required int price,
  required int qty,
  required int minQty,
  required String payment,
  required String delivery,
  Duration validity = const Duration(hours: 24),
  bool seeded = false,
}) =>
    {
      'sellerId': seller.id,
      'sellerName': seller.name,
      'governorate': seller.governorate,
      'productId': product.id,
      'productName': product.name,
      'spec': spec,
      'price': price,
      'qty': qty,
      'minQty': minQty,
      'unit': 'طن',
      'payment': payment,
      'delivery': delivery,
      'status': 'active',
      if (seeded) 'seeded': true,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validity)),
    };

// Prices in EGP/ton, close to the market press of 23–26 Nov 2026. Sample data, not quotes.
const _seedListings = [
  ('wadi_grain', 'yellow_corn', 'برازيلي', 14100, 500, 25, 'كاش', 'تسليم أرض المصنع'),
  ('wadi_grain', 'yellow_corn', 'أوكراني', 13650, 300, 25, 'كاش', 'استلام من المخزن'),
  ('delta_soy', 'soybean_meal', 'بروتين 46%', 24900, 200, 10, 'تحويل بنكي', 'تسليم أرض المصنع'),
  ('delta_soy', 'soybean_meal', 'بروتين 44%', 23900, 150, 10, 'آجل 30 يوم', 'استلام من المصنع'),
  ('wadi_grain', 'wheat_bran', 'خشنة', 14500, 80, 5, 'كاش', 'استلام من المخزن'),
  ('delta_soy', 'soy_hulls', 'محلي', 15000, 60, 5, 'كاش', 'استلام من المصنع'),
];

/// Replaces the sample listings with fresh ones valid for 24 hours (run it before each pitch).
Future<void> seedDemoData() async {
  final db = FirebaseFirestore.instance;
  final listings = db.collection('listings');
  final batch = db.batch();
  for (final old in (await listings.where('seeded', isEqualTo: true).get()).docs) {
    batch.delete(old.reference);
  }
  for (final (sellerId, productId, spec, price, qty, minQty, payment, delivery) in _seedListings) {
    batch.set(
      listings.doc(),
      listingDoc(
        seller: businessById(sellerId),
        product: demoProducts.firstWhere((p) => p.id == productId),
        spec: spec,
        price: price,
        qty: qty,
        minQty: minQty,
        payment: payment,
        delivery: delivery,
        seeded: true,
      ),
    );
  }
  await batch.commit();
}
