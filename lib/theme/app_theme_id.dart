enum AppThemeId { classic, forest, sky, sand, blush }

extension AppThemeIdX on AppThemeId {
  String get firestoreValue => name;

  String get label => switch (this) {
        AppThemeId.classic => 'Classic',
        AppThemeId.forest => 'Forest',
        AppThemeId.sky => 'Sky',
        AppThemeId.sand => 'Sand',
        AppThemeId.blush => 'Blush',
      };

  static AppThemeId parse(String? raw) {
    if (raw == null || raw.isEmpty) return AppThemeId.classic;
    for (final id in AppThemeId.values) {
      if (id.name == raw) return id;
    }
    return AppThemeId.classic;
  }
}
