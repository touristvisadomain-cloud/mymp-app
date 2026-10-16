import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The site's own palette, so the app and mymp.bd are plainly the same thing.
/// The values come from src/app/globals.css; change them there first.
class AppColors {
  static const paper = Color(0xFFF4F5F1);
  static const surface = Color(0xFFFFFFFF);
  static const sunk = Color(0xFFECEEEA);
  static const ink = Color(0xFF17201B);
  static const inkSoft = Color(0xFF465049);
  static const muted = Color(0xFF5E6863);
  static const rule = Color(0xFFDFE3DD);
  static const ruleSoft = Color(0xFFEAEDE8);
  static const brand = Color(0xFF0F6A4B);
  static const brandDark = Color(0xFF0A4D36);
  static const brandSoft = Color(0xFFE3F1E9);
  static const brandRing = Color(0xFFBFE1CF);
  static const warn = Color(0xFF8A6212);
  static const warnSoft = Color(0xFFF8F0DC);
  static const danger = Color(0xFFA8323D);
  static const live = Color(0xFFD7263D);

  /// Party colours, the same ones the website uses, checked for colour-blind
  /// separation before they were chosen.
  static const _party = <String, Color>{
    'BNP': Color(0xFF1F7A4F),
    'Jamaat': Color(0xFF8CBF2A),
    // The site's code for Jamaat (data/parties.json); without it Jamaat drew in the "other" purple.
    'BJEI': Color(0xFF8CBF2A),
    'Ind': Color(0xFF5B6FB5),
    'NCP': Color(0xFFE0641F),
  };
  static const partyOther = Color(0xFF9A5FC7);

  static Color party(String? abbr) => _party[abbr] ?? partyOther;
}

/// Corner radii and spacing, named rather than sprinkled as numbers.
class AppSizes {
  static const radiusCard = 16.0;
  static const radiusPill = 999.0;
  static const gap = 12.0;
  static const pagePad = 16.0;
}

/// Surfaces: a white card lifted off the page by a soft shadow and a hairline,
/// the look the website's cards have.
class AppDecor {
  static const shadow = [
    BoxShadow(color: Color(0x0D17201B), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F17201B), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static BoxDecoration card({double radius = AppSizes.radiusCard}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.ruleSoft),
        boxShadow: shadow,
      );

  /// The green of the page headers, darker at the foot.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12805A), AppColors.brand, AppColors.brandDark],
    stops: [0, 0.55, 1],
  );
}

const _font = 'NotoSansBengali';

/// Bengali needs more room between lines than Latin: the vowel signs sit above
/// and below the letter, and a 1.2 line height crowds them into each other.
TextStyle _bn(
  double size,
  FontWeight weight,
  Color color, {
  double height = 1.45,
}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    surface: AppColors.surface,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: AppColors.paper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: _bn(19, FontWeight.w700, AppColors.ink),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        side: const BorderSide(color: AppColors.rule),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.ruleSoft,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.rule),
      labelStyle: _bn(13.5, FontWeight.w600, AppColors.inkSoft),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: _bn(15, FontWeight.w400, AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandSoft,
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => _bn(
          12,
          s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          s.contains(WidgetState.selected) ? AppColors.brand : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 23,
          color: s.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: _bn(14, FontWeight.w500, Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textTheme: TextTheme(
      displaySmall: _bn(26, FontWeight.w700, AppColors.ink, height: 1.35),
      headlineSmall: _bn(21, FontWeight.w700, AppColors.ink, height: 1.35),
      titleLarge: _bn(18, FontWeight.w700, AppColors.ink),
      titleMedium: _bn(16, FontWeight.w600, AppColors.ink),
      titleSmall: _bn(14.5, FontWeight.w600, AppColors.inkSoft),
      bodyLarge: _bn(15.5, FontWeight.w400, AppColors.ink),
      bodyMedium: _bn(14.5, FontWeight.w400, AppColors.inkSoft),
      bodySmall: _bn(13, FontWeight.w400, AppColors.muted),
      labelLarge: _bn(15, FontWeight.w600, AppColors.ink),
      labelSmall: _bn(12, FontWeight.w500, AppColors.muted),
    ),
  );
}
