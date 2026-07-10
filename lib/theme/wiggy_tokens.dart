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

  static WiggyTokens forId(AppThemeId id, {required bool dark}) {
    switch (id) {
      case AppThemeId.classic:
        return dark ? _classicDark : _classicLight;
      case AppThemeId.forest:
        return dark ? _forestDark : _forestLight;
      case AppThemeId.sky:
        return dark ? _skyDark : _skyLight;
    }
  }

  static const _classicLight = WiggyTokens(
    sectionHeader: Color(0xFFE9C4C7),
    sectionHeaderText: Color(0xFF7A4E55),
    tallyBox: Color(0xFF8FC4E8),
    tallyField: Color(0xFFE3F0FA),
    hairline: Color(0xFFE2E7EF),
    accent: Color(0xFFE2342B),
  );

  static const _classicDark = WiggyTokens(
    sectionHeader: Color(0xFF2A3548),
    sectionHeaderText: Color(0xFFE9C4C7),
    tallyBox: Color(0xFF3A5A78),
    tallyField: Color(0xFF243044),
    hairline: Color(0xFF2E3A4D),
    accent: Color(0xFFE2342B),
  );

  static const _forestLight = WiggyTokens(
    sectionHeader: Color(0xFFA8D5BA),
    sectionHeaderText: Color(0xFF1B4332),
    tallyBox: Color(0xFF6BBF8A),
    tallyField: Color(0xFFE5F4EA),
    hairline: Color(0xFFD0E5D8),
    accent: Color(0xFF2E7D52),
  );

  static const _forestDark = WiggyTokens(
    sectionHeader: Color(0xFF1B4332),
    sectionHeaderText: Color(0xFFC8E6C9),
    tallyBox: Color(0xFF2E7D52),
    tallyField: Color(0xFF14261E),
    hairline: Color(0xFF1F3328),
    accent: Color(0xFF66BB6A),
  );

  static const _skyLight = WiggyTokens(
    sectionHeader: Color(0xFF90CDF4),
    sectionHeaderText: Color(0xFF1A365D),
    tallyBox: Color(0xFF63B3ED),
    tallyField: Color(0xFFEBF8FF),
    hairline: Color(0xFFD0E4F5),
    accent: Color(0xFF3182CE),
  );

  static const _skyDark = WiggyTokens(
    sectionHeader: Color(0xFF1A365D),
    sectionHeaderText: Color(0xFFBEE3F8),
    tallyBox: Color(0xFF2B6CB0),
    tallyField: Color(0xFF122033),
    hairline: Color(0xFF1E2F45),
    accent: Color(0xFF63B3ED),
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

Color primaryForTheme(AppThemeId id, {required bool dark}) {
  switch (id) {
    case AppThemeId.classic:
      return dark ? const Color(0xFF8FC4E8) : const Color(0xFF1B2A4A);
    case AppThemeId.forest:
      return dark ? const Color(0xFF66BB6A) : const Color(0xFF0B3D2E);
    case AppThemeId.sky:
      return dark ? const Color(0xFF63B3ED) : const Color(0xFF1A365D);
  }
}

Color scaffoldForTheme(AppThemeId id, {required bool dark}) {
  if (!dark) {
    switch (id) {
      case AppThemeId.classic:
        return const Color(0xFFF4F6FA);
      case AppThemeId.forest:
        return const Color(0xFFF3F7F4);
      case AppThemeId.sky:
        return const Color(0xFFF0F6FB);
    }
  }
  switch (id) {
    case AppThemeId.classic:
      return const Color(0xFF121820);
    case AppThemeId.forest:
      return const Color(0xFF0D1F17);
    case AppThemeId.sky:
      return const Color(0xFF0B1524);
  }
}

Color surfaceForTheme(AppThemeId id, {required bool dark}) {
  if (!dark) return Colors.white;
  switch (id) {
    case AppThemeId.classic:
      return const Color(0xFF1B2433);
    case AppThemeId.forest:
      return const Color(0xFF14261E);
    case AppThemeId.sky:
      return const Color(0xFF122033);
  }
}

Color onPrimaryForTheme(AppThemeId id, {required bool dark}) {
  if (!dark) return Colors.white;
  switch (id) {
    case AppThemeId.classic:
      return const Color(0xFF121820);
    case AppThemeId.forest:
      return const Color(0xFF0D1F17);
    case AppThemeId.sky:
      return const Color(0xFF0B1524);
  }
}
