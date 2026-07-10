import 'package:flutter/material.dart';

import '../services/store.dart';
import '../theme.dart';
import '../utils/ui_density.dart';
import '../widgets/company_header.dart';
import '../widgets/store_message.dart';

/// Manager appearance settings — density, themes, branding, review link.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _themeBusy = false;
  bool _reviewBusy = false;
  bool _brandBusy = false;
  final _reviewUrl = TextEditingController();
  final _companyName = TextEditingController();
  final _logoUrl = TextEditingController();
  bool _densityBusy = false;
  AppThemeId _themeId = AppThemeId.classic;

  UiDensity get _density => UiDensityController.instance.density;

  @override
  void initState() {
    super.initState();
    final company = Store.instance.activeCompany;
    _themeId = AppThemeIdX.parse(company?.themeId);
    _reviewUrl.text = company?.googleReviewUrl ?? '';
    _companyName.text = company?.name ?? '';
    _logoUrl.text = company?.logoUrl ?? '';
    UiDensityController.instance.addListener(_onDensityChanged);
  }

  void _onDensityChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setDensity(UiDensity d) async {
    setState(() => _densityBusy = true);
    await UiDensityController.instance.setDensity(d);
    if (!mounted) return;
    setState(() => _densityBusy = false);
    showStoreMessage(
      context,
      d == UiDensity.compact
          ? 'Compact — more fits on screen'
          : 'Comfortable — larger controls',
    );
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

  Future<void> _saveBranding() async {
    setState(() => _brandBusy = true);
    final nameErr =
        await Store.instance.updateCompanyName(_companyName.text);
    if (!mounted) return;
    if (nameErr != null) {
      setState(() => _brandBusy = false);
      showStoreMessage(context, nameErr, error: true);
      return;
    }
    final logoErr =
        await Store.instance.updateCompanyLogoUrl(_logoUrl.text);
    if (!mounted) return;
    setState(() => _brandBusy = false);
    if (logoErr == null) {
      _logoUrl.text = Store.instance.activeCompany?.logoUrl ?? '';
      _companyName.text = Store.instance.activeCompany?.name ?? '';
    }
    showStoreMessage(
      context,
      logoErr ?? 'Company branding saved',
      error: logoErr != null,
    );
  }

  @override
  void dispose() {
    UiDensityController.instance.removeListener(_onDensityChanged);
    _reviewUrl.dispose();
    _companyName.dispose();
    _logoUrl.dispose();
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
    final company = Store.instance.activeCompany;
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
                    const Text('Company branding', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Name and logo shown when employees log in with your company code.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    if (company != null) ...[
                      CompanyHeader(company: company, height: 64),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _companyName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _logoUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Logo image URL',
                        hintText: 'https://…/logo.png',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _brandBusy ? null : _saveBranding,
                      child: _brandBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save branding'),
                    ),
                    TextButton(
                      onPressed: _brandBusy
                          ? null
                          : () async {
                              _logoUrl.clear();
                              setState(() => _brandBusy = true);
                              final err = await Store.instance
                                  .updateCompanyLogoUrl('');
                              if (!mounted) return;
                              setState(() => _brandBusy = false);
                              showStoreMessage(
                                this.context,
                                err ?? 'Logo cleared — initials will show',
                                error: err != null,
                              );
                            },
                      child: const Text('Clear logo'),
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
                    const Text('Display density', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Compact zooms the UI slightly and tightens spacing so more fits on this device. Master Sheet density stays separate.',
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
                    const Text('Company theme', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Applies company-wide. Each option is a distinct light palette.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in AppThemeId.values)
                          ChoiceChip(
                            label: Text(id.label),
                            selected: _themeId == id,
                            onSelected: _themeBusy
                                ? null
                                : (_) => _setTheme(id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final id in AppThemeId.values) ...[
                          Expanded(
                            child: Container(
                              height: 36,
                              margin: EdgeInsets.only(
                                right: id == AppThemeId.blush ? 0 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryForTheme(id),
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
