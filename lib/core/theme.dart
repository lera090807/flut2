import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const compactBreakpoint = 600.0;
String money(int kopecks) => NumberFormat.currency(
  locale: 'ru',
  symbol: '₽',
  decimalDigits: kopecks % 100 == 0 ? 0 : 2,
).format(kopecks / 100);
ThemeData cosmeticsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF805266),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFAF8F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAF8F6),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAE2E3)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDED5D8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(Color(0xFFF5EFEE)),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF59474E),
      ),
      dataRowMinHeight: 68,
      dataRowMaxHeight: 76,
      columnSpacing: 24,
    ),
  );
}
