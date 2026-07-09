import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'ww_master_sheet_trends_visuals';

enum TrendsPanelMode { expanded, chipsOnly, hidden }

class TrendsVisualPrefs {
  const TrendsVisualPrefs({
    required this.panelMode,
    required this.showSummary,
    required this.showRevenueOverTime,
    required this.showByEmployee,
    required this.showBaByEmployee,
    required this.showMembershipMix,
  });

  final TrendsPanelMode panelMode;
  final bool showSummary;
  final bool showRevenueOverTime;
  final bool showByEmployee;
  final bool showBaByEmployee;
  final bool showMembershipMix;

  factory TrendsVisualPrefs.defaults() => const TrendsVisualPrefs(
        panelMode: TrendsPanelMode.expanded,
        showSummary: true,
        showRevenueOverTime: true,
        showByEmployee: true,
        showBaByEmployee: true,
        showMembershipMix: true,
      );

  TrendsVisualPrefs copyWith({
    TrendsPanelMode? panelMode,
    bool? showSummary,
    bool? showRevenueOverTime,
    bool? showByEmployee,
    bool? showBaByEmployee,
    bool? showMembershipMix,
  }) {
    return TrendsVisualPrefs(
      panelMode: panelMode ?? this.panelMode,
      showSummary: showSummary ?? this.showSummary,
      showRevenueOverTime: showRevenueOverTime ?? this.showRevenueOverTime,
      showByEmployee: showByEmployee ?? this.showByEmployee,
      showBaByEmployee: showBaByEmployee ?? this.showBaByEmployee,
      showMembershipMix: showMembershipMix ?? this.showMembershipMix,
    );
  }

  Map<String, dynamic> toJson() => {
        'panelMode': panelMode.name,
        'summary': showSummary,
        'revenueOverTime': showRevenueOverTime,
        'byEmployee': showByEmployee,
        'baByEmployee': showBaByEmployee,
        'membershipMix': showMembershipMix,
      };

  factory TrendsVisualPrefs.fromJson(Map<String, dynamic> json) {
    var mode = TrendsPanelMode.expanded;
    for (final m in TrendsPanelMode.values) {
      if (m.name == json['panelMode']) mode = m;
    }
    return TrendsVisualPrefs(
      panelMode: mode,
      showSummary: json['summary'] as bool? ?? true,
      showRevenueOverTime: json['revenueOverTime'] as bool? ?? true,
      showByEmployee: json['byEmployee'] as bool? ?? true,
      showBaByEmployee: json['baByEmployee'] as bool? ?? true,
      showMembershipMix: json['membershipMix'] as bool? ?? true,
    );
  }

  static Future<TrendsVisualPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return TrendsVisualPrefs.defaults();
    try {
      return TrendsVisualPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return TrendsVisualPrefs.defaults();
    }
  }

  static Future<void> save(TrendsVisualPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(value.toJson()));
  }

  bool get anyChartVisible =>
      showRevenueOverTime ||
      showByEmployee ||
      showBaByEmployee ||
      showMembershipMix;

  bool get anyVisible => showSummary || anyChartVisible;
}
