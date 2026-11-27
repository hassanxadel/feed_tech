// Taking or choosing a photo, and showing one.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:feedtech/presentation/widgets/feedback.dart';
import 'package:feedtech/presentation/widgets/pickers.dart';
import 'package:feedtech/services/photo_service.dart';
import 'package:feedtech/shared/constants/app_theme.dart';

/// Lets the user take or choose a photo; it is resized and compressed before upload.
Future<String?> addPhoto(BuildContext context) async {
  final source = await pickOption<ImageSource>(context, 'منين الصورة؟', const [
    Opt(ImageSource.camera, 'صوّر بالكاميرا', icon: Icons.photo_camera),
    Opt(ImageSource.gallery, 'اختار من الصور', icon: Icons.photo_library),
  ], null);
  if (source == null) return null;
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 70);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (!context.mounted) return null;
  if (bytes.length > 500 * 1024) {
    showProblem(context, 'الصورة كبيرة قوي. جرّب صورة تانية.');
    return null;
  }
  String? id;
  await attempt(context, () async => id = await savePhoto(bytes));
  return id;
}

/// A photo from the `photos` collection, or a clear placeholder when there is none.
class PhotoBox extends StatelessWidget {
  const PhotoBox(this.id,
      {super.key, this.size = 84, this.icon = Icons.image_outlined, this.label = 'مفيش صورة', this.circle = false});
  final String? id;
  final double size;
  final IconData icon;
  final String label;
  final bool circle;

  Widget _frame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size : 12),
        child: SizedBox.square(dimension: size, child: child),
      );

  Widget _placeholder(BuildContext context) => _frame(Container(
        color: const Color(0xFFE2E8F0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: size * 0.38, color: C.muted),
          if (size >= 80 && !circle) Text(label, style: tt(context).labelSmall?.copyWith(color: C.muted)),
        ]),
      ));

  @override
  Widget build(BuildContext context) {
    if (id == null || id!.isEmpty) return _placeholder(context);
    return FutureBuilder<Uint8List?>(
      future: loadPhoto(id!),
      builder: (context, s) => s.data == null
          ? (s.connectionState == ConnectionState.done
              ? _placeholder(context)
              : _frame(const ColoredBox(color: Color(0xFFE2E8F0))))
          : _frame(Image.memory(s.data!, fit: BoxFit.cover, semanticLabel: 'صورة')),
    );
  }
}
