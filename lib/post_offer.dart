import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';

/// Reads a whole number typed on any keyboard: Arabic-Indic digits (٢٤٩٠٠), Persian digits,
/// and thousands separators (24,900 / ٢٤٬٩٠٠). Returns null when it isn't a number.
int? parseAmount(String text) {
  final digits = StringBuffer();
  for (final c in text.trim().runes) {
    if (c >= 0x30 && c <= 0x39) {
      digits.writeCharCode(c);
    } else if (c >= 0x660 && c <= 0x669) {
      digits.writeCharCode(c - 0x660 + 0x30); // ٠-٩
    } else if (c >= 0x6F0 && c <= 0x6F9) {
      digits.writeCharCode(c - 0x6F0 + 0x30); // ۰-۹
    } else if (!',٬ '.runes.contains(c)) {
      return null;
    }
  }
  return int.tryParse(digits.toString());
}

class PostOfferScreen extends StatefulWidget {
  const PostOfferScreen({super.key, required this.seller});
  final Business seller;

  @override
  State<PostOfferScreen> createState() => _PostOfferScreenState();
}

class _PostOfferScreenState extends State<PostOfferScreen> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _qty = TextEditingController();
  final _minQty = TextEditingController(text: '5');
  Product _product = demoProducts.first;
  late String _spec = _product.specs.first;
  String _payment = paymentOptions.first;
  String _delivery = deliveryOptions.first;
  int _hours = 24;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _qty.dispose();
    _minQty.dispose();
    super.dispose();
  }

  String? _positive(String? v) {
    final n = parseAmount(v ?? '');
    return n == null || n <= 0 ? 'اكتب رقم صحيح' : null;
  }

  String? _minQtyCheck(String? v) {
    final error = _positive(v);
    if (error != null) return error;
    final qty = parseAmount(_qty.text);
    return qty != null && parseAmount(v!)! > qty ? 'أقل كمية أكبر من الكمية المتاحة' : null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('listings').add(listingDoc(
            seller: widget.seller,
            product: _product,
            spec: _spec,
            price: parseAmount(_price.text)!,
            qty: parseAmount(_qty.text)!,
            minQty: parseAmount(_minQty.text)!,
            payment: _payment,
            delivery: _delivery,
            validity: Duration(hours: _hours),
          ));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم نشر العرض')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false); // keep what was typed so the seller can retry
      messenger.showSnackBar(SnackBar(content: Text('ما اتنشرش العرض، حاول تاني ($e)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    final label = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(title: Text('نشر عرض جديد · ${widget.seller.name}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Product>(
              value: _product,
              decoration: const InputDecoration(labelText: 'المنتج'),
              items: [for (final p in demoProducts) DropdownMenuItem(value: p, child: Text(p.name))],
              onChanged: (p) => setState(() {
                _product = p!;
                _spec = p.specs.first;
              }),
            ),
            gap,
            DropdownButtonFormField<String>(
              key: ValueKey(_product.id), // reset when the product changes
              value: _spec,
              decoration: const InputDecoration(labelText: 'المواصفة'),
              items: [for (final s in _product.specs) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (s) => setState(() => _spec = s!),
            ),
            gap,
            _number(_price, 'سعر الطن (جنيه)', _positive),
            gap,
            Row(children: [
              Expanded(child: _number(_qty, 'الكمية المتاحة (طن)', _positive)),
              const SizedBox(width: 12),
              Expanded(child: _number(_minQty, 'أقل كمية (طن)', _minQtyCheck)),
            ]),
            gap,
            Text('طريقة الدفع', style: label),
            _choices(paymentOptions, _payment, (v) => setState(() => _payment = v)),
            gap,
            Text('التوصيل', style: label),
            _choices(deliveryOptions, _delivery, (v) => setState(() => _delivery = v)),
            gap,
            Text('العرض صالح لمدة', style: label),
            Wrap(spacing: 8, children: [
              for (final h in const [12, 24, 48])
                ChoiceChip(
                  label: Text('$h ساعة'),
                  selected: _hours == h,
                  onSelected: (_) => setState(() => _hours = h),
                ),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('نشر العرض'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _number(TextEditingController c, String label, FormFieldValidator<String> validator) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      );

  Widget _choices(List<String> options, String selected, ValueChanged<String> onPick) => Wrap(
        spacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(label: Text(o), selected: o == selected, onSelected: (_) => onPick(o)),
        ],
      );
}
