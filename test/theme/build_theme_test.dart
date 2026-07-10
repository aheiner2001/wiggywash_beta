import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wiggywash/theme.dart';
import 'package:wiggywash/theme/app_theme_id.dart';
import 'package:wiggywash/theme/wiggy_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('classic light tokens and primary', () {
    final tokens = WiggyTokens.forId(AppThemeId.classic, dark: false);
    expect(tokens.sectionHeader, const Color(0xFFE9C4C7));
    expect(primaryForTheme(AppThemeId.classic, dark: false),
        const Color(0xFF1B2A4A));
  });

  test('classic dark uses dark scaffold', () {
    expect(scaffoldForTheme(AppThemeId.classic, dark: true),
        const Color(0xFF121820));
    expect(primaryForTheme(AppThemeId.classic, dark: true),
        const Color(0xFF8FC4E8));
  });

  test('forest primary differs from classic', () {
    expect(
      primaryForTheme(AppThemeId.classic, dark: false),
      isNot(equals(primaryForTheme(AppThemeId.forest, dark: false))),
    );
  });

  test('buildTheme attaches WiggyTokens extension', () {
    final t = buildTheme(themeId: AppThemeId.forest, dark: false);
    expect(t.brightness, Brightness.light);
    expect(t.extension<WiggyTokens>(), isNotNull);
    expect(t.colorScheme.primary, primaryForTheme(AppThemeId.forest, dark: false));
  });
}
