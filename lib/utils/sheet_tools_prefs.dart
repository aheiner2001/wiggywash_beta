import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sheet_column.dart';

const _kPrefsKey = 'ww_master_sheet_tools';

class SheetToolsPrefs {
  const SheetToolsPrefs({
    required this.density,
    required this.sortKey,
    required this.sortAsc,
    required this.minBa,
    required this.minRevenue,
    required this.hiddenColumnIds,
  });

  final SheetDensity density;
  final SheetSortKey sortKey;
  final bool sortAsc;
  final double? minBa;
  final double? minRevenue;
  final Set<String> hiddenColumnIds;

  factory SheetToolsPrefs.defaults() => const SheetToolsPrefs(
        density: SheetDensity.comfortable,
        sortKey: SheetSortKey.nameOrDate,
        sortAsc: true,
        minBa: null,
        minRevenue: null,
        hiddenColumnIds: {},
      );

  bool isColumnVisible(String id) {
    if (id == SheetColumnId.first) return true;
    return !hiddenColumnIds.contains(id);
  }

  SheetToolsPrefs copyWith({
    SheetDensity? density,
    SheetSortKey? sortKey,
    bool? sortAsc,
    double? minBa,
    bool clearMinBa = false,
    double? minRevenue,
    bool clearMinRevenue = false,
    Set<String>? hiddenColumnIds,
  }) {
    return SheetToolsPrefs(
      density: density ?? this.density,
      sortKey: sortKey ?? this.sortKey,
      sortAsc: sortAsc ?? this.sortAsc,
      minBa: clearMinBa ? null : (minBa ?? this.minBa),
      minRevenue: clearMinRevenue ? null : (minRevenue ?? this.minRevenue),
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'density': density.name,
        'sortKey': sortKey.name,
        'sortAsc': sortAsc,
        'minBa': minBa,
        'minRevenue': minRevenue,
        'hidden': hiddenColumnIds.toList(),
      };

  factory SheetToolsPrefs.fromJson(Map<String, dynamic> json) {
    SheetDensity density = SheetDensity.comfortable;
    for (final d in SheetDensity.values) {
      if (d.name == json['density']) density = d;
    }
    SheetSortKey sortKey = SheetSortKey.nameOrDate;
    for (final k in SheetSortKey.values) {
      if (k.name == json['sortKey']) sortKey = k;
    }
    final hidden = <String>{};
    final rawHidden = json['hidden'];
    if (rawHidden is List) {
      for (final e in rawHidden) {
        if (e is String) hidden.add(e);
      }
    }
    return SheetToolsPrefs(
      density: density,
      sortKey: sortKey,
      sortAsc: json['sortAsc'] as bool? ?? true,
      minBa: (json['minBa'] as num?)?.toDouble(),
      minRevenue: (json['minRevenue'] as num?)?.toDouble(),
      hiddenColumnIds: hidden,
    );
  }

  static Future<SheetToolsPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return SheetToolsPrefs.defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SheetToolsPrefs.fromJson(map);
    } catch (_) {
      return SheetToolsPrefs.defaults();
    }
  }

  static Future<void> save(SheetToolsPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(value.toJson()));
  }

  double rowHeight() => switch (density) {
        SheetDensity.comfortable => 40,
        SheetDensity.compact => 32,
        SheetDensity.dense => 26,
      };

  double headerHeight() => switch (density) {
        SheetDensity.comfortable => 104,
        SheetDensity.compact => 92,
        SheetDensity.dense => 80,
      };

  double bodyFontSize() => switch (density) {
        SheetDensity.comfortable => 12.5,
        SheetDensity.compact => 12,
        SheetDensity.dense => 11,
      };
}
