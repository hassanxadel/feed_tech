import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';

// Sign-in is phone number + a 6-digit PIN the user chooses (no SMS: SMS sign-in needs the Blaze plan).
// Firebase email/password sign-in is used underneath; the phone becomes a hidden login name.
// shortcut: phone numbers are not verified by SMS; switch to phone auth after upgrading to Blaze.

/// "01012345678" / "+20 10 1234 5678" / Arabic digits → "+201012345678", or null if not an Egyptian mobile.
String? toE164(String raw) {
  var d = westernDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('20') && d.length == 12) d = '0${d.substring(2)}';
  return RegExp(r'^01[0125]\d{8}$').hasMatch(d) ? '+2$d' : null;
}

String loginName(String e164) => '${e164.substring(1)}@phone.feedtech.app';

String? _pinOf(String raw) {
  final p = westernDigits(raw).trim();
  return RegExp(r'^\d{6}$').hasMatch(p) ? p : null;
}

String authMessage(Object e) {
  final code = e is FirebaseAuthException ? e.code : '';
  return switch (code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' =>
      'الرقم أو الرقم السري مش مظبوط. راجعهم وجرّب تاني. لو أول مرة، اعمل حساب جديد.',
    'email-already-in-use' => 'الرقم ده عنده حساب بالفعل. ارجع وادخل برقمك والرقم السري.',
    'too-many-requests' => 'حاولت كتير. استنى شوية وجرّب تاني.',
    'network-request-failed' => 'النت ضعيف. اتأكد إنه شغال وجرّب تاني.',
    'operation-not-allowed' => 'الدخول مش متاح دلوقتي. كلّمنا وهنحلها بسرعة.',
    _ => 'حصلت مشكلة. جرّب تاني بعد دقيقة.',
  };
}

Widget _phoneField(BuildContext context, TextEditingController c, String? error) => TextField(
      controller: c,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      autofillHints: const [AutofillHints.telephoneNumber],
      style: tt(context).headlineSmall?.copyWith(letterSpacing: 2),
      decoration: InputDecoration(hintText: 'مثال: 01012345678', errorText: error, errorMaxLines: 3),
    );

Widget _pinField(BuildContext context, TextEditingController c, {String? error, VoidCallback? onDone}) => TextField(
      controller: c,
      keyboardType: TextInputType.number,
      obscureText: true,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofillHints: const [AutofillHints.password],
      style: tt(context).headlineSmall?.copyWith(letterSpacing: 10),
      decoration: InputDecoration(hintText: '••••••', counterText: '', errorText: error, errorMaxLines: 3),
      onSubmitted: (_) => onDone?.call(),
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(), _pin = TextEditingController();
  String? _phoneError, _pinError;
  bool _busy = false;

  Future<void> _login() async {
    final e164 = toE164(_phone.text), pin = _pinOf(_pin.text);
    setState(() {
      _phoneError = e164 == null ? 'اكتب رقم موبايل مصري صحيح، 11 رقم بيبدأ بـ 01' : null;
      _pinError = pin == null ? 'الرقم السري 6 أرقام' : null;
    });
    if (e164 == null || pin == null) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: loginName(e164), password: pin);
    } catch (e) {
      if (mounted) setState(() => _pinError = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: AutofillGroup(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(size: 88)),
              const SizedBox(height: 12),
              Text('أهلاً بيك في فيد تك', style: tt(context).headlineMedium, textAlign: TextAlign.center),
              Text('سوق خامات الأعلاف في مكان واحد',
                  style: tt(context).bodyLarge?.copyWith(color: C.muted), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Text('رقم موبايلك', style: tt(context).titleLarge),
              const SizedBox(height: 8),
              _phoneField(context, _phone, _phoneError),
              const SizedBox(height: 16),
              Text('الرقم السري (6 أرقام)', style: tt(context).titleLarge),
              const SizedBox(height: 8),
              _pinField(context, _pin, error: _pinError, onDone: _login),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _login,
                icon: _busy
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.login),
                label: Text(_busy ? 'بندخّلك…' : 'دخول'),
              ),
              const SizedBox(height: 28),
              Text('أول مرة تستخدم فيد تك؟', style: tt(context).titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountScreen())),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('اعمل حساب جديد'),
              ),
              const SizedBox(height: 12),
              Text('نسيت الرقم السري؟ كلّمنا وهنساعدك ترجّعه.', style: tt(context).bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

/// New account: phone + a PIN typed twice. The company details come next (SignUpScreen).
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _phone = TextEditingController(), _pin = TextEditingController(), _pin2 = TextEditingController();
  String? _phoneError, _pinError, _pin2Error;
  bool _busy = false;

  Future<void> _create() async {
    final e164 = toE164(_phone.text), pin = _pinOf(_pin.text);
    setState(() {
      _phoneError = e164 == null ? 'اكتب رقم موبايل مصري صحيح، 11 رقم بيبدأ بـ 01' : null;
      _pinError = pin == null ? 'اختار 6 أرقام تفتكرها' : null;
      _pin2Error = pin != null && _pinOf(_pin2.text) != pin ? 'الرقمين مش زي بعض. اكتبه تاني.' : null;
    });
    if (e164 == null || pin == null || _pin2Error != null) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: loginName(e164), password: pin);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _phoneError = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('حساب جديد')),
        body: AutofillGroup(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text('رقم موبايلك', style: tt(context).titleLarge),
            const SizedBox(height: 8),
            _phoneField(context, _phone, _phoneError),
            const SizedBox(height: 20),
            Text('اختار رقم سري من 6 أرقام', style: tt(context).titleLarge),
            Text('هتدخل بيه كل مرة. اختار رقم سهل تفتكره ومحدش يعرفه.', style: tt(context).bodyMedium),
            const SizedBox(height: 8),
            _pinField(context, _pin, error: _pinError),
            const SizedBox(height: 20),
            Text('اكتب الرقم السري تاني', style: tt(context).titleLarge),
            const SizedBox(height: 8),
            _pinField(context, _pin2, error: _pin2Error, onDone: _create),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('التالي'),
            ),
          ),
        ),
      );
}

/// First-time profile: name, company, area, and whether the business mainly buys or sells.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with DraftForm {
  bool _busy = false;
  @override
  String get draftKey => 'signup';
  @override
  Json defaults() => {'name': '', 'company': '', 'area': null, 'role': null};

  Future<void> _next() async {
    final missing = switch (step) {
      1 => (v['name'] as String).trim().length < 2 ? 'اكتب اسمك' : null,
      2 => (v['company'] as String).trim().length < 2 ? 'اكتب اسم المصنع أو الشركة' : null,
      3 => v['area'] == null ? 'اختار المكان' : null,
      _ => v['role'] == null ? 'اختار نوع شغلكم' : null,
    };
    if (missing != null) return showProblem(context, missing);
    if (step < 4) return go(step + 1);
    setState(() => _busy = true);
    final ok = await attempt(context, () async {
      await (db.batch()
            ..set(db.doc('users/$myUid'), {
              'name': (v['name'] as String).trim(),
              'company': (v['company'] as String).trim(),
              'area': v['area'],
              'role': v['role'],
              'materials': <String>[],
              'gallery': <String>[],
              'about': '',
              'years': 0,
              'createdAt': FieldValue.serverTimestamp(),
            })
            ..set(db.doc('users/$myUid/private/contact'), {'phone': Me.phone}))
          .commit();
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Drafts.clear(draftKey);
      showDone(context, 'أهلاً بيك يا ${(v['name'] as String).trim()} ✓');
    }
  }

  Widget _text(String key, String label) => TextFormField(
        key: ValueKey('$key$restored'),
        initialValue: v[key] as String,
        autofocus: true,
        style: tt(context).titleMedium,
        decoration: InputDecoration(hintText: label),
        onChanged: (t) => set(key, t),
        onFieldSubmitted: (_) => _next(),
      );

  @override
  Widget build(BuildContext context) => StepFlow(
        title: 'بيانات الشركة',
        step: step,
        total: 4,
        busy: _busy,
        banner: restoredBanner,
        nextLabel: step == 4 ? 'ابدأ' : 'التالي',
        onNext: _next,
        onBack: step == 1 ? () => FirebaseAuth.instance.signOut() : back,
        child: switch (step) {
          1 => Column(children: [const Ask('اسمك إيه؟'), _text('name', 'مثال: محمود عبد الله')]),
          2 => Column(children: [
              const Ask('اسم المصنع أو الشركة', hint: 'ده الاسم اللي التجار والمصانع هيشوفوه'),
              _text('company', 'مثال: مصنع النور للأعلاف'),
            ]),
          3 => Column(children: [
              const Ask('المصنع أو المخزن فين؟'),
              Options<String>(items: areaOptions(), selected: v['area'] as String?, onSelect: (a) => set('area', a)),
            ]),
          _ => Column(children: [
              const Ask('شغلكم الأساسي إيه؟', hint: 'تقدر تشتري وتبيع في أي وقت مهما اخترت'),
              Options<String>(
                items: const [
                  Opt('buy', 'بنشتري خامات', sub: 'مصنع أعلاف بيشتري ذرة وصويا وغيرهم', icon: Icons.factory),
                  Opt('sell', 'بنبيع خامات', sub: 'تاجر أو مورد أو مصنع خامات', icon: Icons.storefront),
                  Opt('both', 'بنشتري وبنبيع', icon: Icons.sync_alt),
                ],
                selected: v['role'] as String?,
                onSelect: (r) => set('role', r),
              ),
            ]),
        },
      );
}
