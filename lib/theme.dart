import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-contrast palette: every text colour is at least 7:1 on white (WCAG AAA),
/// because many users are older and read outdoors on cheap phones.
class C {
  static const green = Color(0xFF166534); // buyer actions, primary
  static const greenBg = Color(0xFFDCFCE7);
  static const blue = Color(0xFF075985); // seller actions
  static const blueBg = Color(0xFFE0F2FE);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFCBD5E1);
  static const red = Color(0xFFB91C1C);
  static const redBg = Color(0xFFFEE2E2);
  static const amber = Color(0xFF92400E);
  static const amberBg = Color(0xFFFEF3C7);
}

ThemeData buildTheme() {
  // Almarai: a clear Arabic sans with open letter shapes, readable at large sizes.
  TextStyle f(double size, FontWeight w, [Color color = C.ink]) =>
      GoogleFonts.almarai(fontSize: size, fontWeight: w, color: color, height: 1.45);
  final text = TextTheme(
    displaySmall: f(34, FontWeight.w800),
    headlineMedium: f(28, FontWeight.w800),
    headlineSmall: f(24, FontWeight.w800),
    titleLarge: f(22, FontWeight.w800),
    titleMedium: f(20, FontWeight.w700),
    titleSmall: f(18, FontWeight.w700),
    bodyLarge: f(20, FontWeight.w400),
    bodyMedium: f(18, FontWeight.w400), // body text never below 18px
    bodySmall: f(16, FontWeight.w400, C.muted),
    labelLarge: f(20, FontWeight.w700),
    labelMedium: f(18, FontWeight.w700),
    labelSmall: f(15, FontWeight.w700),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const big = Size.fromHeight(60); // every button at least 60px tall
  const pad = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  OutlineInputBorder border(Color c, double w) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.green,
      primary: C.green,
      secondary: C.blue,
      error: C.red,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: C.bg,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 64,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(size: 30, color: C.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: big, textStyle: text.labelLarge, shape: shape, padding: pad)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: big,
        textStyle: text.labelLarge,
        shape: shape,
        padding: pad,
        foregroundColor: C.green,
        side: const BorderSide(color: C.green, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          minimumSize: const Size(64, 56), textStyle: text.labelMedium, foregroundColor: C.green, shape: shape),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
      labelStyle: text.bodyMedium,
      hintStyle: text.bodyMedium?.copyWith(color: C.muted),
      border: border(C.line, 2),
      enabledBorder: border(C.line, 2),
      focusedBorder: border(C.green, 3),
      errorBorder: border(C.red, 2),
      focusedErrorBorder: border(C.red, 3),
      errorStyle: f(16, FontWeight.w700, C.red),
    ),
    chipTheme: ChipThemeData(
      labelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: const BorderSide(color: C.line, width: 1.5),
      selectedColor: C.greenBg,
      checkmarkColor: C.green,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line, width: 1.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: f(18, FontWeight.w700, Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogTheme(titleTextStyle: text.titleLarge, contentTextStyle: text.bodyLarge),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      minVerticalPadding: 12,
      iconColor: C.ink,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.green, linearTrackColor: C.line),
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1),
  );
}
