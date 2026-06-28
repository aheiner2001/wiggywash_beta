import 'package:flutter/material.dart';

import '../models/location.dart';
import '../models/worker.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/store_message.dart';

/// Landing page. Employees enter their site code, then pick their name. A
/// "Manager sign in" button opens the Google-based manager flow.
class SiteCodeScreen extends StatefulWidget {
  const SiteCodeScreen({super.key});

  @override
  State<SiteCodeScreen> createState() => _SiteCodeScreenState();
}

class _SiteCodeScreenState extends State<SiteCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  Location? _location; // set once a valid code is entered

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    setState(() => _busy = true);
    final loc = await Store.instance.lookupSiteCode(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (loc == null) {
      showStoreMessage(context, 'No site found for that code.', error: true);
      return;
    }
    Store.instance.previewLocation(loc.id);
    setState(() => _location = loc);
  }

  Future<void> _promptAdmin() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin access'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Admin password',
            hintText: 'Enter admin password',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    final err = await Store.instance.signInSuperAdmin(code);
    if (!mounted) return;
    if (err != null) {
      showStoreMessage(context, err, error: true);
    }
    // On success the app routes straight to the Super Admin screen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const BrandHeader(),
                  const SizedBox(height: 28),
                  if (_location == null)
                    _CodeCard(
                      controller: _code,
                      busy: _busy,
                      onContinue: _checkCode,
                    )
                  else
                    _NamePickerCard(
                      location: _location!,
                      onBack: () => setState(() => _location = null),
                    ),
                  const SizedBox(height: 16),
                  if (_location == null) ...[
                    TextButton.icon(
                      onPressed: () => Store.instance.openManagerAuth(),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Manager sign in'),
                    ),
                    TextButton.icon(
                      onPressed: _promptAdmin,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Admin access'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.controller,
    required this.busy,
    required this.onContinue,
  });
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter site code', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'Ask your manager for your location\'s code.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Site code',
              hintText: 'e.g. OMAHA1',
            ),
            onSubmitted: (_) => onContinue(),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: busy ? null : onContinue,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _NamePickerCard extends StatefulWidget {
  const _NamePickerCard({required this.location, required this.onBack});
  final Location location;
  final VoidCallback onBack;

  @override
  State<_NamePickerCard> createState() => _NamePickerCardState();
}

class _NamePickerCardState extends State<_NamePickerCard> {
  final _pin = TextEditingController();
  Worker? _selected;
  String? _pinError;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final worker = _selected;
    if (worker == null) return;
    if (worker.requiresPin && !worker.verifyPin(_pin.text)) {
      setState(() => _pinError = 'Incorrect entry code');
      return;
    }
    await Store.instance.signInEmployee(
      locationId: widget.location.id,
      name: worker.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final workers = Store.instance.workers;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(widget.location.displayName,
                        style: TextStyles.subheading),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Select your name', style: TextStyles.caption),
              const SizedBox(height: 10),
              if (workers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No names on the roster yet. Ask your manager to add you.',
                    style: TextStyles.caption,
                  ),
                )
              else
                ...workers.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: _selected?.id == w.id
                          ? AppColors.navy
                          : AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        onTap: () => setState(() {
                          _selected = w;
                          _pin.clear();
                          _pinError = null;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.name,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: _selected?.id == w.id
                                            ? Colors.white
                                            : AppColors.navy,
                                      ),
                                    ),
                                    if (w.requiresPin)
                                      Text(
                                        'Code required',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _selected?.id == w.id
                                              ? Colors.white70
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_selected?.id == w.id)
                                const Icon(Icons.check_rounded,
                                    color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_selected?.requiresPin == true) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Entry code',
                    hintText: 'Enter code',
                    errorText: _pinError,
                  ),
                  onChanged: (_) => setState(() => _pinError = null),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _selected == null ? null : _continue,
                child: const Text('Start scorecard'),
              ),
            ],
          );
        },
      ),
    );
  }
}
