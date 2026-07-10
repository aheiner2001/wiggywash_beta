import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/store.dart';
import '../theme.dart';
import '../utils/brand_color.dart';
import '../utils/ui_density.dart';
import '../widgets/store_message.dart';

/// Manager appearance settings — company brand color (accent-only).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _presets = <Color>[
    Color(0xFF1B2A4A),
    Color(0xFF2E7D52),
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
  ];

  Color _draft = AppColors.navy;
  bool _busy = false;
  final _hex = TextEditingController();
  UiDensity _density = UiDensity.comfortable;
  bool _densityBusy = false;

  @override
  void initState() {
    super.initState();
    final existing =
        parseBrandColor(Store.instance.activeCompany?.primaryColor);
    if (existing != null) _draft = existing;
    _hex.text = formatBrandColor(_draft);
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

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setDraft(Color c) {
    setState(() {
      _draft = c;
      _hex.text = formatBrandColor(c);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await Store.instance
        .updateCompanyPrimaryColor(formatBrandColor(_draft));
    if (!mounted) return;
    setState(() => _busy = false);
    showStoreMessage(
      context,
      err ?? 'Brand color saved',
      error: err != null,
    );
  }

  void _applyHexField() {
    final parsed = parseBrandColor(_hex.text);
    if (parsed == null) {
      showStoreMessage(context, 'Enter a valid hex like #2E7D52', error: true);
      return;
    }
    _setDraft(parsed);
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
                      onSelectionChanged: _densityBusy
                          ? null
                          : (s) => _setDensity(s.first),
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
                    const Text('Brand color', style: TextStyles.subheading),
                    const SizedBox(height: 6),
                    const Text(
                      'Applies company-wide to buttons, nav, and accents.',
                      style: TextStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in _presets)
                          GestureDetector(
                            onTap: () => _setDraft(c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _draft.toARGB32() == c.toARGB32()
                                      ? AppColors.textPrimary
                                      : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _hex,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F#]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Custom hex',
                        hintText: '#2E7D52',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _applyHexField(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _applyHexField,
                        child: const Text('Apply hex'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Preview', style: TextStyles.caption),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _draft,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {},
                      child: const Text('Primary button'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save brand color'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _setDraft(AppColors.navy),
                      child: const Text('Reset to default navy'),
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
