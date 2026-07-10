enum AppThemeId { classic, forest, sky }

extension AppThemeIdX on AppThemeId {
  String get firestoreValue => name;

  static AppThemeId parse(String? raw) {
    if (raw == null || raw.isEmpty) return AppThemeId.classic;
    for (final id in AppThemeId.values) {
      if (id.name == raw) return id;
    }
    return AppThemeId.classic;
  }
}
