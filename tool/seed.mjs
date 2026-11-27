// Fills Firestore with realistic Egyptian demo data for the last 30 days.
//
//   cd tool && npm install && node seed.mjs
//
// Before running: create both test accounts in the app (phone 01000000001 = buyer,
// 01000000002 = seller, PIN 123456 for both) and finish sign-up, so their accounts exist.
//
// How it writes without an admin key: it signs in anonymously, deploys a temporary rule that
// lets only that sign-in read/write, writes the data, and ALWAYS redeploys firestore.rules.
// It deletes the old demo collections first (listings, rfqs, deals) and replaces all app data.
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import {
  Timestamp, collection, doc, getDoc, getDocs, getFirestore, setDoc, writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const PROJECT = 'feedtech-fabe2';
const BUYER_PHONE = '+201000000001';
const SELLER_PHONE = '+201000000002';

// ── Firebase (web config read from lib/firebase_options.dart) ───────────────
const opts = readFileSync(join(root, 'lib/firebase_options.dart'), 'utf8');
const web = opts.slice(opts.indexOf('FirebaseOptions web'));
const val = (k) => web.match(new RegExp(`${k}: '([^']+)'`))[1];
const app = initializeApp({ apiKey: val('apiKey'), appId: val('appId'), projectId: val('projectId'), authDomain: val('authDomain') });
const db = getFirestore(app);

const deploy = (config) => execSync(
  `firebase deploy --only firestore:rules --project ${PROJECT}${config ? ` --config "${config}"` : ''}`,
  { cwd: root, stdio: 'inherit' });

// ── Deterministic randomness, dates ─────────────────────────────────────────
let seed = 20261127;
const rand = () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const pick = (a) => a[Math.floor(rand() * a.length)];
const now = new Date();
const dayStart = (d) => new Date(now.getFullYear(), now.getMonth(), now.getDate() - d);
const daysAhead = (d) => new Date(now.getFullYear(), now.getMonth(), now.getDate() + d);
const hoursAgo = (h) => new Date(now.getTime() - h * 3600e3);
const ts = (d) => Timestamp.fromDate(d);
const dayKey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const r50 = (x) => Math.round(x / 50) * 50;

// ── Catalogue ───────────────────────────────────────────────────────────────
const materials = {
  soybean_meal: {
    name: 'كسب صويا', icon: 'grain', order: 1, base: 24900,
    specs: [
      { key: 'protein', label: 'البروتين', kind: 'min', unit: '%', options: [44, 46, 48] },
      { key: 'moisture', label: 'الرطوبة', kind: 'max', unit: '%', options: [11, 12, 12.5, 13] },
      { key: 'origin', label: 'المنشأ', kind: 'choice', unit: '', options: ['محلي', 'مستورد'] },
    ],
    adj: (s) => (s.protein === 44 ? -900 : s.protein === 48 ? 700 : 0) + (s.origin === 'مستورد' ? 200 : 0) + (s.moisture >= 13 ? -150 : 0),
  },
  yellow_corn: {
    name: 'ذرة صفراء', icon: 'grass', order: 2, base: 13950,
    specs: [
      { key: 'moisture', label: 'الرطوبة', kind: 'max', unit: '%', options: [12, 13, 14, 15] },
      { key: 'origin', label: 'المنشأ', kind: 'choice', unit: '', options: ['برازيلي', 'أرجنتيني', 'أوكراني', 'أمريكي'] },
    ],
    adj: (s) => ({ 'أوكراني': -450, 'أمريكي': -100, 'أرجنتيني': 50 }[s.origin] ?? 0) + (s.moisture >= 15 ? -200 : 0),
  },
  soybeans: {
    name: 'فول صويا', icon: 'eco', order: 3, base: 25800,
    specs: [
      { key: 'protein', label: 'البروتين', kind: 'min', unit: '%', options: [34, 35, 36, 37, 38] },
      { key: 'moisture', label: 'الرطوبة', kind: 'max', unit: '%', options: [11, 12, 13, 14] },
      { key: 'origin', label: 'المنشأ', kind: 'choice', unit: '', options: ['برازيلي', 'أرجنتيني', 'أمريكي', 'باراجواي'] },
    ],
    adj: (s) => (s.protein - 36) * 250 + (s.origin === 'أمريكي' ? 150 : 0),
  },
  bran: {
    name: 'ردة (نخالة قمح)', icon: 'bran', order: 4, base: 14400,
    specs: [
      { key: 'type', label: 'النوع', kind: 'choice', unit: '', options: ['خشنة', 'ناعمة'] },
      { key: 'moisture', label: 'الرطوبة', kind: 'max', unit: '%', options: [12, 13, 14] },
    ],
    adj: (s) => (s.type === 'ناعمة' ? -300 : 0),
  },
};

// Market trend per material: ~4.5% higher 30 days ago (October spike), easing with daily noise.
const trend = {};
for (const id of Object.keys(materials)) {
  const f = [];
  f[29] = 1.045 + (rand() - 0.5) * 0.01;
  for (let d = 28; d >= 0; d--) f[d] = f[d + 1] - 0.045 / 29 + (rand() - 0.5) * 0.008;
  const today = f[0];
  trend[id] = f.map((x) => x / today);
}

// ── Companies ───────────────────────────────────────────────────────────────
const owners = ['محمد السيد', 'أحمد عبد الرحمن', 'محمود فتحي', 'حسن إبراهيم', 'خالد منصور', 'مصطفى عادل', 'عمرو سعيد',
  'إبراهيم الشافعي', 'طارق عبد العزيز', 'سامح نبيل', 'وليد حمدي', 'ياسر جمال', 'هشام رشاد', 'علي عبد الله', 'كريم صلاح'];
const sellers = [
  ['النيل للحبوب والأعلاف', 'السادات'], ['الشرق لتجارة الحبوب', 'العاشر من رمضان'], ['المتحدة للزيوت والأكساب', 'برج العرب'],
  ['الأهرام للخامات', '6 أكتوبر'], ['الوادي الأخضر للتجارة', 'العبور'], ['السلام للأعلاف والحبوب', 'السادات'],
  ['الإسكندرية للصويا', 'برج العرب'], ['المصرية لتجارة الذرة', 'العاشر من رمضان'], ['الفجر للخامات الزراعية', '6 أكتوبر'],
  ['الرواد للاستيراد والتصدير', 'العبور'], ['الخير للحبوب', 'السادات'], ['الصفوة لكسب الصويا', 'برج العرب'],
  ['العربي للتجارة والتوريدات', 'العاشر من رمضان'], ['البركة للخامات', 'العبور'], ['المستقبل للأعلاف', '6 أكتوبر'],
  ['الحرمين للحبوب', 'السادات'], ['الجوهرة للاستيراد', 'برج العرب'], ['الريادة لتجارة الذرة', 'العبور'],
].map(([company, area], i) => ({ id: `seller_${String(i + 1).padStart(2, '0')}`, company, area, role: 'sell', phone: `+2010000001${String(i + 10)}` }));
const buyers = [
  ['مصنع الريف للأعلاف', 'السادات'], ['مصنع الفيروز للأعلاف', 'العاشر من رمضان'], ['مصنع الأمل لأعلاف الدواجن', 'العبور'],
  ['مصنع الصقر للأعلاف', '6 أكتوبر'], ['مصنع البحيرة للأعلاف', 'برج العرب'], ['مصنع الشروق للأعلاف', 'السادات'],
  ['مصنع الندى لأعلاف المواشي', 'العاشر من رمضان'], ['مصنع الواحة للأعلاف', '6 أكتوبر'], ['مصنع الحصاد للأعلاف', 'العبور'],
  ['مصنع الضحى للأعلاف السمكية', 'برج العرب'],
].map(([company, area], i) => ({ id: `buyer_${String(i + 1).padStart(2, '0')}`, company, area, role: 'buy', phone: `+2010000002${String(i + 10)}` }));

// What each seller trades (the soybean-meal sellers come first so test-buyer offers have senders).
const sells = ['soybean_meal', 'yellow_corn', 'soybean_meal', 'yellow_corn', 'bran', 'soybean_meal', 'soybeans', 'yellow_corn',
  'bran', 'soybeans', 'yellow_corn', 'soybean_meal', 'bran', 'yellow_corn', 'soybean_meal', 'soybeans', 'yellow_corn', 'yellow_corn'];
const second = { 1: 'bran', 3: 'soybean_meal', 6: 'soybean_meal', 9: 'yellow_corn', 12: 'yellow_corn', 15: 'soybean_meal' };

// ── Writer ──────────────────────────────────────────────────────────────────
const ops = [];
const put = (path, data) => ops.push([path, data]);
const newId = (col) => doc(collection(db, col)).id;

async function commitAll() {
  for (let i = 0; i < ops.length; i += 400) {
    const b = writeBatch(db);
    for (const [p, d] of ops.slice(i, i + 400)) b.set(doc(db, p), d);
    await b.commit();
    process.stdout.write(`  wrote ${Math.min(i + 400, ops.length)}/${ops.length}\r`);
  }
  console.log();
}

async function wipe() {
  const sub = { users: ['private'], negotiations: ['steps'], orders: ['contacts'], deals: ['offers'], rfqs: ['quotes'] };
  for (const col of ['listings', 'rfqs', 'deals', 'users', 'ads', 'priceHistory', 'dailyPrices', 'requests',
    'negotiations', 'orders', 'notifications', 'photos', 'materials']) {
    const snap = await getDocs(collection(db, col));
    const refs = [];
    for (const d of snap.docs) {
      for (const s of sub[col] ?? []) (await getDocs(collection(d.ref, s))).forEach((x) => refs.push(x.ref));
      refs.push(d.ref);
    }
    for (let i = 0; i < refs.length; i += 400) {
      const b = writeBatch(db);
      refs.slice(i, i + 400).forEach((r) => b.delete(r));
      await b.commit();
    }
    if (refs.length) console.log(`  deleted ${refs.length} from ${col}`);
  }
}

// ── Data ────────────────────────────────────────────────────────────────────
function build(buyerUid, sellerUid) {
  const testBuyer = { id: buyerUid, company: 'مصنع النور للأعلاف', area: 'السادات', role: 'buy', phone: BUYER_PHONE,
    name: 'الحاج محمود عبد الله', years: 18, about: 'مصنع أعلاف دواجن ومواشي بطاقة 200 طن في اليوم. بنشتري ذرة صفراء وكسب صويا وردة بشكل يومي.' };
  const testSeller = { id: sellerUid, company: 'الدلتا لكسب الصويا', area: 'العاشر من رمضان', role: 'sell', phone: SELLER_PHONE,
    name: 'م. أحمد سالم', years: 12, about: 'مصنع استخلاص زيت وكسب صويا. بنورّد كسب صويا 44% و46% وفول صويا مستورد لمصانع الأعلاف في الدلتا والقاهرة.' };
  const company = Object.fromEntries([...sellers, ...buyers, testBuyer, testSeller].map((c) => [c.id, c]));

  for (const m of Object.entries(materials)) {
    const [id, { name, icon, order, specs }] = m;
    put(`materials/${id}`, { name, icon, order, specs });
  }

  const sellerMaterials = {};
  sellers.forEach((s, i) => { sellerMaterials[s.id] = [sells[i], ...(second[i] ? [second[i]] : [])]; });
  sellerMaterials[sellerUid] = ['soybean_meal', 'soybeans'];

  for (const c of [...sellers, ...buyers, testBuyer, testSeller]) {
    put(`users/${c.id}`, {
      name: c.name ?? pick(owners), company: c.company, area: c.area, role: c.role,
      materials: sellerMaterials[c.id] ?? [], gallery: [], about: c.about ?? '', years: c.years ?? 3 + Math.floor(rand() * 25),
      createdAt: ts(dayStart(40 + Math.floor(rand() * 60))),
    });
    put(`users/${c.id}/private/contact`, { phone: c.phone });
  }

  // Ads with daily price updates for 30 days (+ the price history that feeds the charts).
  const ads = [];
  const staleIdx = new Set([3, 9, 14, 20]);
  const addAd = (sellerId, materialId, specs, o = {}) => {
    const m = materials[materialId];
    const id = newId('ads');
    const offset = o.offset ?? (rand() - 0.5) * 0.03;
    const last = o.lastDay ?? (staleIdx.has(ads.length) ? 3 + Math.floor(rand() * 4) : (rand() < 0.85 ? 0 : 1));
    const qty = o.qty ?? 50 + 25 * Math.floor(rand() * 22);
    const history = [];
    for (let d = 29; d >= last; d--) {
      if (d !== last && rand() > 0.8) continue;
      let at = new Date(dayStart(d).getTime() + (8 + rand() * 6) * 3600e3);
      if (at > now) at = new Date(now.getTime() - (20 + rand() * 60) * 60e3);
      const price = o.price && d === last ? o.price : r50((m.base + m.adj(specs)) * trend[materialId][d] * (1 + offset) + (rand() - 0.5) * 200);
      history.push({ at, price });
    }
    const lastH = history[history.length - 1];
    const delivers = o.delivers ?? rand() < 0.6;
    const ad = {
      sellerId, company: company[sellerId].company, area: company[sellerId].area, materialId, specs, qty,
      minOrder: o.minOrder ?? pick([5, 10, 10, 25]),
      price: lastH.price,
      payments: o.payments ?? ['cash', ...(rand() < 0.7 ? ['transfer'] : []), ...(rand() < 0.3 ? ['deferred'] : [])],
      delivers, deliveryDays: delivers ? (o.deliveryDays ?? pick([0, 1, 1, 2, 3, 7])) : 0,
      photos: [], notes: o.notes ?? '', active: true, priceAt: ts(lastH.at), createdAt: ts(dayStart(30)),
    };
    put(`ads/${id}`, ad);
    for (const h of history) put(`priceHistory/${newId('priceHistory')}`, { adId: id, sellerId, materialId, price: h.price, qty, at: ts(h.at) });
    ads.push({ id, ad, history });
    return { id, ad };
  };
  const randomSpecs = (materialId) => Object.fromEntries(materials[materialId].specs.map((s) => {
    if (s.kind === 'max') return [s.key, s.options[Math.floor(rand() * Math.min(3, s.options.length))]];
    if (s.key === 'protein' && materialId === 'soybean_meal') return [s.key, pick([44, 46, 46, 46, 48])];
    return [s.key, pick(s.options)];
  }));
  for (const s of sellers) for (const mId of sellerMaterials[s.id]) addAd(s.id, mId, randomSpecs(mId));
  const sellerAd46 = addAd(sellerUid, 'soybean_meal', { protein: 46, moisture: 12, origin: 'محلي' },
    { lastDay: 0, qty: 300, minOrder: 10, payments: ['cash', 'transfer', 'deferred'], delivers: true, deliveryDays: 1, offset: -0.004,
      notes: 'التحميل من المصنع في العاشر من رمضان، ومعاه شهادة تحليل.' });
  addAd(sellerUid, 'soybeans', { protein: 36, moisture: 12, origin: 'برازيلي' },
    { lastDay: 3, qty: 120, minOrder: 25, payments: ['cash', 'transfer'], delivers: false });

  // Daily averages: each ad's latest price as of that day, if updated within 48 hours.
  for (const mId of Object.keys(materials)) {
    for (let d = 29; d >= 0; d--) {
      const asOf = d === 0 ? now : new Date(dayStart(d - 1).getTime() - 1);
      const prices = [];
      for (const a of ads.filter((x) => x.ad.materialId === mId)) {
        const h = a.history.filter((x) => x.at <= asOf).pop();
        if (h && asOf - h.at <= 48 * 3600e3) prices.push(h.price);
      }
      if (!prices.length) continue;
      const day = dayKey(dayStart(d));
      put(`dailyPrices/${mId}_${day}`, {
        materialId: mId, day, avg: Math.round(prices.reduce((a, b) => a + b, 0) / prices.length / 10) * 10,
        min: Math.min(...prices), max: Math.max(...prices), count: prices.length, at: ts(asOf),
      });
    }
  }

  // Requests, negotiations (with their full history), orders, notifications.
  const note = (to, from, type, text, kind, target, read, hours) =>
    put(`notifications/${newId('notifications')}`, { to, from, type, text, kind, target, read, at: ts(hoursAgo(hours)) });
  const request = (buyerId, materialId, qty, specs, budget, inDays, payment, o = {}) => {
    const id = newId('requests');
    put(`requests/${id}`, {
      buyerId, company: company[buyerId].company, area: o.area ?? company[buyerId].area, materialId, qty, specs, budget,
      deliveryDate: ts(daysAhead(inDays)), payment, notes: o.notes ?? '', open: o.open ?? true, createdAt: ts(hoursAgo(o.hoursAgo ?? 5)),
    });
    return id;
  };
  // steps: [[by, kind, price, qty, hoursAgo]]
  const negotiation = (buyerId, sellerId, materialId, specs, steps, o = {}) => {
    const id = newId('negotiations');
    let price = steps[0][2], qty = steps[0][3], lastBy = steps[0][0], status = 'negotiating';
    for (const [by, kind, p, q] of steps) {
      if (kind === 'counter' || kind === 'offer') { price = p; qty = q; lastBy = by; }
      if (kind === 'accept') status = 'agreed';
      if (kind === 'decline') status = 'declined';
      if (kind === 'cancel') status = 'cancelled';
    }
    const at = ts(hoursAgo(steps[steps.length - 1][4]));
    put(`negotiations/${id}`, {
      buyerId, sellerId, parties: [buyerId, sellerId], buyerCompany: company[buyerId].company, sellerCompany: company[sellerId].company,
      materialId, specs, price, qty, deliveryDate: ts(daysAhead(o.inDays ?? 3)), payment: o.payment ?? 'cash',
      place: o.place ?? company[buyerId].area, note: '', ...(o.requestId ? { requestId: o.requestId } : {}), ...(o.adId ? { adId: o.adId } : {}),
      ...(o.orderId ? { orderId: o.orderId } : {}), status, lastBy, createdAt: ts(hoursAgo(steps[0][4])), updatedAt: at,
    });
    for (const [by, kind, p, q, h] of steps) put(`negotiations/${id}/steps/${newId('steps')}`, { by, kind, price: p, qty: q, note: '', at: ts(hoursAgo(h)) });
    return id;
  };
  const order = (negoId, buyerId, sellerId, materialId, specs, qty, price, status, o = {}) => {
    const id = o.id;
    put(`orders/${id}`, {
      negotiationId: negoId, buyerId, sellerId, parties: [buyerId, sellerId], buyerCompany: company[buyerId].company,
      sellerCompany: company[sellerId].company, materialId, specs, qty, price, total: qty * price, payment: o.payment ?? 'transfer',
      deliveryDate: ts(o.delivery ?? daysAhead(3)), place: company[buyerId].area, status,
      createdAt: ts(hoursAgo(o.hoursAgo ?? 30)), updatedAt: ts(hoursAgo((o.hoursAgo ?? 30) - 2)),
    });
    put(`orders/${id}/contacts/${buyerId}`, { phone: company[buyerId].phone });
    if (status !== 'new') put(`orders/${id}/contacts/${sellerId}`, { phone: company[sellerId].phone });
    return id;
  };
  const B = buyerUid, S = sellerUid;
  const mealSellers = sellers.filter((s) => sellerMaterials[s.id].includes('soybean_meal'));
  const cornSellers = sellers.filter((s) => sellerMaterials[s.id].includes('yellow_corn'));
  const branSellers = sellers.filter((s) => sellerMaterials[s.id].includes('bran'));

  // Test buyer: 70 t soybean meal 46% — three offers to compare.
  const r1 = request(B, 'soybean_meal', 70, { protein: 46, moisture: null, origin: null }, 24800, 2, 'transfer',
    { notes: 'مطلوب شهادة تحليل مع الشحنة', hoursAgo: 9 });
  [[mealSellers[0], 24950, 6, false], [mealSellers[3], 24700, 4, false], [mealSellers[1], 25200, 2, true]].forEach(([s, p, h, unread]) => {
    const n = negotiation(B, s.id, 'soybean_meal', { protein: 46, moisture: 12, origin: 'محلي' }, [[s.id, 'offer', p, 70, h]],
      { requestId: r1, inDays: 2, payment: 'transfer' });
    note(B, s.id, 'offer', `${s.company} بعتلك عرض: 70 طن كسب صويا بـ ${p.toLocaleString('en')} جنيه للطن`, 'negotiation', n, !unread, h);
  });
  // Test buyer: 100 t corn — the buyer countered, waiting for the seller.
  const r2 = request(B, 'yellow_corn', 100, { moisture: 14, origin: null }, 13800, 7, 'cash', { hoursAgo: 30 });
  negotiation(B, cornSellers[0].id, 'yellow_corn', { moisture: 13, origin: 'برازيلي' },
    [[cornSellers[0].id, 'offer', 13950, 100, 26], [B, 'counter', 13750, 100, 20]], { requestId: r2, inDays: 7 });
  // Test buyer agreed on a bran ad; the order is still to be completed.
  const branAd = ads.find((a) => a.ad.sellerId === branSellers[0].id);
  const nb = negotiation(B, branSellers[0].id, 'bran', branAd.ad.specs,
    [[B, 'offer', branAd.ad.price - 200, 40, 7], [branSellers[0].id, 'accept', branAd.ad.price - 200, 40, 3]], { adId: branAd.id, inDays: 4 });
  note(B, branSellers[0].id, 'accept', `${branSellers[0].company} وافق على ${(branAd.ad.price - 200).toLocaleString('en')} جنيه للطن — ردة. كمّلوا الطلبية`, 'negotiation', nb, false, 3);

  // Test seller: requests waiting in the feed, a counter-offer and an offer on the ad to answer.
  const r3 = request(buyers[0].id, 'soybean_meal', 50, { protein: 44, moisture: null, origin: null }, 23900, 3, 'cash', { hoursAgo: 4 });
  const r4 = request(buyers[2].id, 'soybeans', 30, { protein: null, moisture: 12, origin: 'برازيلي' }, 25700, 7, 'transfer', { hoursAgo: 11 });
  note(S, buyers[0].id, 'request', `${buyers[0].company} محتاج 50 طن كسب صويا — قدّم عرضك`, 'request', r3, false, 4);
  note(S, buyers[2].id, 'request', `${buyers[2].company} محتاج 30 طن فول صويا — قدّم عرضك`, 'request', r4, false, 11);
  const r5 = request(buyers[1].id, 'soybean_meal', 40, { protein: 46, moisture: null, origin: null }, 24600, 2, 'deferred', { hoursAgo: 20 });
  const n5 = negotiation(buyers[1].id, S, 'soybean_meal', { protein: 46, moisture: 12, origin: 'محلي' },
    [[S, 'offer', 24850, 40, 18], [buyers[1].id, 'counter', 24600, 40, 2]], { requestId: r5, inDays: 2, payment: 'deferred' });
  note(S, buyers[1].id, 'counter', `${buyers[1].company} رد بسعر جديد: 24,600 جنيه للطن على كسب صويا`, 'negotiation', n5, false, 2);
  const n6 = negotiation(buyers[3].id, S, 'soybean_meal', sellerAd46.ad.specs, [[buyers[3].id, 'offer', 24500, 40, 1]], { adId: sellerAd46.id, inDays: 3 });
  note(S, buyers[3].id, 'offer', `${buyers[3].company} بعتلك عرض: 40 طن كسب صويا بـ 24,500 جنيه للطن`, 'negotiation', n6, false, 1);

  // Orders: confirmed between the test accounts, a new one for the seller to confirm, a delivered one for the buyer.
  const o1 = newId('orders');
  const n7 = negotiation(B, S, 'soybean_meal', sellerAd46.ad.specs,
    [[B, 'offer', 24500, 40, 52], [S, 'counter', 24700, 40, 50], [B, 'accept', 24700, 40, 49]], { adId: sellerAd46.id, orderId: o1, payment: 'transfer' });
  order(n7, B, S, 'soybean_meal', sellerAd46.ad.specs, 40, 24700, 'confirmed', { id: o1, hoursAgo: 48, delivery: daysAhead(2) });
  note(B, S, 'order-confirmed', `${testSeller.company} أكّد الطلبية — رقم تليفونه ظهر عندك`, 'order', o1, true, 45);
  const o2 = newId('orders');
  const soyAd = ads.find((a) => a.ad.sellerId === S && a.ad.materialId === 'soybeans');
  const n8 = negotiation(buyers[8].id, S, 'soybeans', soyAd.ad.specs,
    [[buyers[8].id, 'offer', 25700, 25, 8], [S, 'counter', 25900, 25, 6], [buyers[8].id, 'accept', 25900, 25, 5]], { adId: soyAd.id, orderId: o2 });
  order(n8, buyers[8].id, S, 'soybeans', soyAd.ad.specs, 25, 25900, 'new', { id: o2, hoursAgo: 4, payment: 'cash' });
  note(S, buyers[8].id, 'order', `طلبية جديدة من ${buyers[8].company}: 25 طن فول صويا — أكّدها`, 'order', o2, false, 4);
  const r0 = request(B, 'yellow_corn', 60, { moisture: 14, origin: null }, 14300, 1, 'transfer', { open: false, hoursAgo: 14 * 24 });
  const kheir = sellers.find((s) => s.company === 'الخير للحبوب');
  const o3 = newId('orders');
  const n9 = negotiation(B, kheir.id, 'yellow_corn', { moisture: 13, origin: 'برازيلي' },
    [[kheir.id, 'offer', 14350, 60, 14 * 24 - 2], [B, 'counter', 14200, 60, 14 * 24 - 5], [kheir.id, 'accept', 14200, 60, 14 * 24 - 6]],
    { requestId: r0, orderId: o3, payment: 'transfer' });
  order(n9, B, kheir.id, 'yellow_corn', { moisture: 13, origin: 'برازيلي' }, 60, 14200, 'delivered', { id: o3, hoursAgo: 13 * 24, delivery: dayStart(12) });

  // Other market activity (not shown to the test accounts, but makes the market realistic).
  const others = [
    [buyers[4].id, 'yellow_corn', 150, { moisture: 14, origin: null }, 13700, 5, 'cash'],
    [buyers[5].id, 'bran', 30, { type: 'خشنة', moisture: null }, 14200, 3, 'cash'],
    [buyers[6].id, 'yellow_corn', 80, { moisture: 13, origin: 'أرجنتيني' }, 14000, 2, 'transfer'],
    [buyers[7].id, 'soybean_meal', 60, { protein: 46, moisture: 12, origin: null }, 24700, 4, 'transfer'],
    [buyers[9].id, 'bran', 20, { type: null, moisture: 13 }, 14100, 7, 'deferred'],
  ];
  others.forEach(([b, m, q, sp, budget, d, pay], i) => {
    const rid = request(b, m, q, sp, budget, d, pay, { hoursAgo: 3 + i * 7 });
    const s = (m === 'yellow_corn' ? cornSellers : m === 'bran' ? branSellers : mealSellers)[i % 2 + 1];
    negotiation(b, s.id, m, randomSpecs(m), [[s.id, 'offer', r50(budget * 1.01), q, 2 + i * 6]], { requestId: rid, inDays: d, payment: pay });
  });
  const o4 = newId('orders');
  const n10 = negotiation(buyers[5].id, cornSellers[2].id, 'yellow_corn', { moisture: 14, origin: 'أوكراني' },
    [[buyers[5].id, 'offer', 13450, 120, 100], [cornSellers[2].id, 'accept', 13450, 120, 98]], { orderId: o4 });
  order(n10, buyers[5].id, cornSellers[2].id, 'yellow_corn', { moisture: 14, origin: 'أوكراني' }, 120, 13450, 'delivered', { id: o4, hoursAgo: 96, delivery: dayStart(2) });
  const o5 = newId('orders');
  const n11 = negotiation(buyers[7].id, mealSellers[2].id, 'soybean_meal', { protein: 44, moisture: 12, origin: 'محلي' },
    [[mealSellers[2].id, 'offer', 23800, 30, 60], [buyers[7].id, 'accept', 23800, 30, 58]], { orderId: o5 });
  order(n11, buyers[7].id, mealSellers[2].id, 'soybean_meal', { protein: 44, moisture: 12, origin: 'محلي' }, 30, 23800, 'cancelled', { id: o5, hoursAgo: 56 });

  return { ads: ads.length, history: ads.reduce((n, a) => n + a.history.length, 0) };
}

// ── Run ─────────────────────────────────────────────────────────────────────
const seeder = (await signInAnonymously(getAuth(app))).user.uid;
writeFileSync(join(here, 'seed.rules'), `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // TEMPORARY (seed script only): just this one sign-in may read and write.
    match /{document=**} { allow read, write: if request.auth != null && request.auth.uid == '${seeder}'; }
  }
}
`);
writeFileSync(join(here, 'firebase.seed.json'), JSON.stringify({ firestore: { rules: 'seed.rules' } }));
console.log('1/4 Opening a temporary write window for this script…');
deploy(join(here, 'firebase.seed.json'));
try {
  // New rules can take a few seconds to apply.
  for (let i = 0; ; i++) {
    try { await setDoc(doc(db, '_seed/ping'), { at: Timestamp.now() }); break; } catch (e) {
      if (i > 20) throw e;
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  // Find the two test accounts by the phone saved at sign-up (users/{uid}/private/contact).
  const found = {};
  for (const u of (await getDocs(collection(db, 'users'))).docs) {
    const phone = (await getDoc(doc(db, `users/${u.id}/private/contact`))).data()?.phone;
    if (phone === BUYER_PHONE || phone === SELLER_PHONE) found[phone] = u.id;
  }
  for (const phone of [BUYER_PHONE, SELLER_PHONE]) {
    if (!found[phone]) throw new Error(`No account for ${phone} yet. Create it in the app (PIN 123456) and finish sign-up, then run again.`);
  }
  console.log('2/4 Removing old data…');
  await wipe();
  console.log('3/4 Writing demo data…');
  const stats = build(found[BUYER_PHONE], found[SELLER_PHONE]);
  await commitAll();
  const b = writeBatch(db); b.delete(doc(db, '_seed/ping')); await b.commit();
  console.log(`   ${stats.ads} ads, ${stats.history} price updates, ${sellers.length} sellers, ${buyers.length} buyers + 2 test accounts`);
} finally {
  console.log('4/4 Restoring the real security rules…');
  deploy();
}
process.exit(0);
