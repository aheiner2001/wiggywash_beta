import 'package:flutter/material.dart';

/// Parses `#RRGGBB` or `RRGGBB` into a Color. Returns null if invalid.
Color? parseBrandColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String formatBrandColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
