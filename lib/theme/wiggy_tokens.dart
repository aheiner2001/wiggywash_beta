import 'package:flutter/material.dart';

import 'app_theme_id.dart';

@immutable
class WiggyTokens extends ThemeExtension<WiggyTokens> {
  const WiggyTokens({
    required this.sectionHeader,
    required this.sectionHeaderText,
    required this.tallyBox,
    required this.tallyField,
    required this.hairline,
    required this.accent,
  });

  final Color sectionHeader;
  final Color sectionHeaderText;
  final Color tallyBox;
  final Color tallyField;
  final Color hairline;
  final Color accent;

  static WiggyTokens forId(AppThemeId id, {bool dark = false}) {
    // Dark mode removed — always light tokens.
    switch (id) {
      case AppThemeId.classic:
        return _classic;
      case AppThemeId.forest:
        return _forest;
      case AppThemeId.sky:
        return _sky;
      case AppThemeId.sand:
        return _sand;
      case AppThemeId.blush:
        return _blush;
    }
  }

  /// Navy + red brand, cool blue tallies.
  static const _classic = WiggyTokens(
    sectionHeader: Color(0xFFE9C4C7),
    sectionHeaderText: Color(0xFF7A4E55),
    tallyBox: Color(0xFF8FC4E8),
    tallyField: Color(0xFFE3F0FA),
    hairline: Color(0xFFE2E7EF),
    accent: Color(0xFFE2342B),
  );

  /// Deep green ops — mint headers, green tallies.
  static const _forest = WiggyTokens(
    sectionHeader: Color(0xFFB7E4C7),
    sectionHeaderText: Color(0xFF081C15),
    tallyBox: Color(0xFF40916C),
    tallyField: Color(0xFFD8F3DC),
    hairline: Color(0xFFB7C9BE),
    accent: Color(0xFF1B4332),
  );

  /// Cool blue — icy fields, strong blue accent.
  static const _sky = WiggyTokens(
    sectionHeader: Color(0xFFBEE3F8),
    sectionHeaderText: Color(0xFF0C2D48),
    tallyBox: Color(0xFF2B6CB0),
    tallyField: Color(0xFFE6F4FF),
    hairline: Color(0xFFB8D4EA),
    accent: Color(0xFF1A4B8C),
  );

  /// Warm light sand — cream surfaces, amber accent.
  static const _sand = WiggyTokens(
    sectionHeader: Color(0xFFF3E0C4),
    sectionHeaderText: Color(0xFF5C3D1E),
    tallyBox: Color(0xFFD4A373),
    tallyField: Color(0xFFFFF8EF),
    hairline: Color(0xFFE8D9C4),
    accent: Color(0xFFB5651D),
  );

  /// Soft blush — pale rose headers, rose accent.
  static const _blush = WiggyTokens(
    sectionHeader: Color(0xFFF8D7E0),
    sectionHeaderText: Color(0xFF6B2D45),
    tallyBox: Color(0xFFE8A0B0),
    tallyField: Color(0xFFFFF0F4),
    hairline: Color(0xFFF0D0DA),
    accent: Color(0xFFC2185B),
  );

  @override
  WiggyTokens copyWith({
    Color? sectionHeader,
    Color? sectionHeaderText,
    Color? tallyBox,
    Color? tallyField,
    Color? hairline,
    Color? accent,
  }) =>
      WiggyTokens(
        sectionHeader: sectionHeader ?? this.sectionHeader,
        sectionHeaderText: sectionHeaderText ?? this.sectionHeaderText,
        tallyBox: tallyBox ?? this.tallyBox,
        tallyField: tallyField ?? this.tallyField,
        hairline: hairline ?? this.hairline,
        accent: accent ?? this.accent,
      );

  @override
  WiggyTokens lerp(ThemeExtension<WiggyTokens>? other, double t) {
    if (other is! WiggyTokens) return this;
    return WiggyTokens(
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      sectionHeaderText:
          Color.lerp(sectionHeaderText, other.sectionHeaderText, t)!,
      tallyBox: Color.lerp(tallyBox, other.tallyBox, t)!,
      tallyField: Color.lerp(tallyField, other.tallyField, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

Color primaryForTheme(AppThemeId id, {bool dark = false}) {
  switch (id) {
    case AppThemeId.classic:
      return const Color(0xFF1B2A4A);
    case AppThemeId.forest:
      return const Color(0xFF081C15);
    case AppThemeId.sky:
      return const Color(0xFF0C2D48);
    case AppThemeId.sand:
      return const Color(0xFF5C3D1E);
    case AppThemeId.blush:
      return const Color(0xFF6B2D45);
  }
}

Color scaffoldForTheme(AppThemeId id, {bool dark = false}) {
  switch (id) {
    case AppThemeId.classic:
      return const Color(0xFFF4F6FA);
    case AppThemeId.forest:
      return const Color(0xFFEFF7F1);
    case AppThemeId.sky:
      return const Color(0xFFEEF5FB);
    case AppThemeId.sand:
      return const Color(0xFFFAF6F0);
    case AppThemeId.blush:
      return const Color(0xFFFCF5F7);
  }
}

Color surfaceForTheme(AppThemeId id, {bool dark = false}) => Colors.white;

Color onPrimaryForTheme(AppThemeId id, {bool dark = false}) => Colors.white;
