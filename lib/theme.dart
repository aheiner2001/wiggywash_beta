import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Wiggy Wash. Mirrors the physical scorecard:
/// white background, soft rose/pink section headers, blue tally boxes, and
/// dark navy text + buttons. Tweak everything from here.
class AppColors {
  static const navy = Color(0xFF1B2A4A); // dark navy — text + buttons
  static const navyDark = Color(0xFF12203B);
  static const rose = Color(0xFFE9C4C7); // soft rose section header
  static const roseText = Color(0xFF7A4E55); // muted maroon label on rose
  static const blue = Color(0xFF8FC4E8); // blue tally box
  static const blueSoft = Color(0xFFE3F0FA); // light blue field fill
  static const background = Color(0xFFF4F6FA); // near-white app background
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFFE2342B); // Wiggy Wash red (logo)
  static const textPrimary = Color(0xFF1B2A4A);
  static const textMuted = Color(0xFF74808F);
  static const hairline = Color(0xFFE2E7EF);
  static const success = Color(0xFF2E7D52);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFB00020);
}

/// Maps a BA actual vs. goal to a status color: green = met, amber = close
/// (within 75% of goal), red = below. Navy when no goal is set.
Color baColor(double actual, double goal) {
  if (goal <= 0) return AppColors.navy;
  if (actual >= goal) return AppColors.success;
  if (actual >= goal * 0.75) return AppColors.warning;
  return AppColors.danger;
}

class AppRadius {
  static const card = 18.0;
  static const button = 14.0;
  static const field = 12.0;
  static const pill = 999.0;
}

class AppSpacing {
  static const page = 16.0;
  static const gap = 12.0;
  static const item = 8.0;
}

ThemeData buildTheme({Color? primary}) {
  final brand = primary ?? AppColors.navy;
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: brand,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: brand,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        disabledBackgroundColor: AppColors.hairline,
        disabledForegroundColor: AppColors.textMuted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: brand, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.blueSoft,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: brand, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brand;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return brand.withValues(alpha: 0.45);
        }
        return null;
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textPrimary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return null;
        }),
      ),
    ),
  );
}

/// A reusable elevated white card surface.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B2A4A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rose pill-shaped section header, e.g. "MEMBERSHIP TALLY".
class SectionPill extends StatelessWidget {
  const SectionPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.roseText,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

class TextStyles {
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static const subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(fontSize: 16, color: AppColors.textPrimary);
  static const caption = TextStyle(fontSize: 13, color: AppColors.textMuted);
}
