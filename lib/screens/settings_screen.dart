import 'package:flutter/material.dart';

import '../services/store.dart';
import '../theme.dart';
import '../utils/ui_density.dart';
import '../widgets/store_message.dart';

/// Manager appearance settings — density, themes, dark mode, review link.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _themeBusy = false;
  bool _reviewBusy = false;
  final _reviewUrl = TextEditingController();
  UiDensity _density = UiDensity.comfortable;
  bool _densityBusy = false;
  AppThemeId _themeId = AppThemeId.classic;

  @override
  void initState() {
    super.initState();
    _themeId = AppThemeIdX.parse(Store.instance.activeCompany?.themeId);
    _reviewUrl.text = Store.instance.activeCompany?.googleReviewUrl ?? '';
    UiDensityPrefs.load().then((p) {
      if (!mounted) return;
      setState(() => _density = p.density);
    });
  }

  Future<void> _setDensity(UiDensity d) async {
    setState(() {
      _density = d;
      _densityBusy = true;
    });
    await UiDensityPrefs.save(UiDensityPrefs(density: d));
    if (!mounted) return;
    setState(() => _densityBusy = false);
    showStoreMessage(context, 'Density saved on this device');
  }

  Future<void> _setTheme(AppThemeId id) async {
    setState(() {
      _themeId = id;
      _themeBusy = true;
    });
    final err = await Store.instance.updateCompanyThemeId(id.firestoreValue);
    if (!mounted) return;
    setState(() => _themeBusy = false);
    if (err != null) {
      setState(() {
        _themeId = AppThemeIdX.parse(Store.instance.activeCompany?.themeId);
      });
    }
    showStoreMessage(
      context,
      err ?? 'Theme saved for the company',
      error: err != null,
    );
  }

  @override
  void dispose() {
    _reviewUrl.dispose();
    super.dispose();
  }

  Future<void> _saveReviewUrl() async {
    setState(() => _reviewBusy = true);
    final err =
        await Store.instance.updateCompanyGoogleReviewUrl(_reviewUrl.text);
    if (!mounted) return;
    setState(() => _reviewBusy = false);
    if (err == null) {
      _reviewUrl.text = Store.instance.activeCompany?.googleReviewUrl ?? '';
    }
    showStoreMessage(
      context,
      err ??
          (_reviewUrl.text.trim().isEmpty
              ? 'Review link cleared'
              : 'Review link saved'),
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Display density', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Comfortable or Compact for dashboard, scorecard, and login on this device. Master Sheet density stays separate.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<UiDensity>(
                      segments: const [
                        ButtonSegment(
                          value: UiDensity.comfortable,
                          label: Text('Comfortable'),
                        ),
                        ButtonSegment(
                          value: UiDensity.compact,
                          label: Text('Compact'),
                        ),
                      ],
                      selected: {_density},
                      onSelectionChanged:
                          _densityBusy ? null : (s) => _setDensity(s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Dark mode', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'This device only. Uses the dark variant of the company theme.',
                      style: TextStyles.caption,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use dark mode'),
                      value: Store.instance.darkMode,
                      onChanged: (v) => Store.instance.setDarkMode(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Company theme', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Applies company-wide to Team, Sheet, Scorecard, and dashboard.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<AppThemeId>(
                      segments: const [
                        ButtonSegment(
                          value: AppThemeId.classic,
                          label: Text('Classic'),
                        ),
                        ButtonSegment(
                          value: AppThemeId.forest,
                          label: Text('Forest'),
                        ),
                        ButtonSegment(
                          value: AppThemeId.sky,
                          label: Text('Sky'),
                        ),
                      ],
                      selected: {_themeId},
                      onSelectionChanged:
                          _themeBusy ? null : (s) => _setTheme(s.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final id in AppThemeId.values) ...[
                          Expanded(
                            child: Container(
                              height: 36,
                              margin: EdgeInsets.only(
                                right: id == AppThemeId.sky ? 0 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: primaryForTheme(id, dark: false),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _themeId == id
                                      ? AppColors.textPrimary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Google review link',
                        style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste your Google review or Maps link. Staff can open a QR from the scorecard and dashboard for customers to scan.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _reviewUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Review URL',
                        hintText: 'https://g.page/r/...',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reviewBusy ? null : _saveReviewUrl,
                      child: _reviewBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save review link'),
                    ),
                    TextButton(
                      onPressed: _reviewBusy
                          ? null
                          : () {
                              _reviewUrl.clear();
                              _saveReviewUrl();
                            },
                      child: const Text('Clear review link'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
