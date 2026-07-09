import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/utils/brand_color.dart';

void main() {
  test('parseBrandColor accepts #RRGGBB', () {
    expect(parseBrandColor('#2E7D52'), const Color(0xFF2E7D52));
  });

  test('parseBrandColor accepts RRGGBB without hash', () {
    expect(parseBrandColor('1B2A4A'), const Color(0xFF1B2A4A));
  });

  test('parseBrandColor returns null for invalid', () {
    expect(parseBrandColor(null), isNull);
    expect(parseBrandColor(''), isNull);
    expect(parseBrandColor('zzz'), isNull);
    expect(parseBrandColor('#12'), isNull);
  });

  test('formatBrandColor writes #RRGGBB', () {
    expect(formatBrandColor(const Color(0xFF2E7D52)), '#2E7D52');
  });
}
