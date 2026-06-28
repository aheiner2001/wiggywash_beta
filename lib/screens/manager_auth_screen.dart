import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/store_message.dart';

/// Manager / Super-Admin entry: sign in with an existing Google account, or
/// create a manager account (admin password → Google → choose a site).
class ManagerAuthScreen extends StatefulWidget {
  const ManagerAuthScreen({super.key});

  @override
  State<ManagerAuthScreen> createState() => _ManagerAuthScreenState();
}

class _ManagerAuthScreenState extends State<ManagerAuthScreen> {
  final _password = TextEditingController();
  final _newLocation = TextEditingController();
  final _newSiteCode = TextEditingController();

  bool _creating = false; // toggled "create account" mode (pre sign-in)
  bool _busy = false;

  List<Location> _locations = [];
  String? _selectedLocationId; // null = create a new site

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locs = await Store.instance.fetchLocations();
    if (!mounted) return;
    setState(() => _locations = locs);
  }

  @override
  void dispose() {
    _password.dispose();
    _newLocation.dispose();
    _newSiteCode.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn({required bool creating}) async {
    if (creating && _password.text.trim().isEmpty) {
      showStoreMessage(context, 'Enter the admin password first.', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await Store.instance.signInWithGoogle(creating: creating);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showStoreMessage(context, err, error: true);
    // On success the screen rebuilds; if no role yet, the "complete" step shows.
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final err = await Store.instance.redeemAccessCode(
      _password.text,
      locationId: _selectedLocationId,
      newLocationName: _selectedLocationId == null ? _newLocation.text : null,
      newSiteCode: _selectedLocationId == null ? _newSiteCode.text : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showStoreMessage(context, err, error: true);
    // On success the user gets a role and is routed to their dashboard.
  }

  void _back() {
    Store.instance.signOutManager();
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
              child: AnimatedBuilder(
                animation: Store.instance,
                builder: (context, _) {
                  final appUser = Store.instance.appUser;
                  final signedInNoRole = appUser != null && appUser.role == null;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const BrandHeader(),
                      const SizedBox(height: 24),
                      if (signedInNoRole)
                        _completeStep(appUser.email)
                      else if (_creating)
                        _createStep()
                      else
                        _signInStep(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back to site code'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInStep() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Manager sign in', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text('Use the Google account on your manager profile.',
              style: TextStyles.caption),
          const SizedBox(height: 18),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            ElevatedButton.icon(
              onPressed: () => _googleSignIn(creating: false),
              icon: const Icon(Icons.account_circle_rounded),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => setState(() => _creating = true),
              child: const Text('Create a manager account'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _createStep() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create manager account', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'Enter the admin password, then sign in with the Google account '
            'you want to use as a manager.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Admin password',
              hintText: 'Enter admin password',
            ),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            ElevatedButton.icon(
              onPressed: () => _googleSignIn(creating: true),
              icon: const Icon(Icons.account_circle_rounded),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _creating = false),
              child: const Text('I already have an account'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completeStep(String email) {
    // If they already typed the admin password in the create step, don't ask
    // again — just pick the site.
    final needPassword = !Store.instance.pendingManagerCreate;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Finish setup', style: TextStyles.subheading),
          const SizedBox(height: 6),
          Text(
            needPassword
                ? 'Signed in as $email. Enter the admin password and choose '
                    'your site.'
                : 'Signed in as $email. Choose your site to finish.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 16),
          if (needPassword) ...[
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin password',
                hintText: 'Enter admin password',
              ),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String?>(
            initialValue: _selectedLocationId,
            decoration: const InputDecoration(labelText: 'Site'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('+ Create a new site'),
              ),
              ..._locations.map(
                (l) => DropdownMenuItem<String?>(
                  value: l.id,
                  child: Text(l.displayName),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedLocationId = v),
          ),
          if (_selectedLocationId == null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _newLocation,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'New site name',
                hintText: 'e.g. Omaha — 144th St',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newSiteCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Site code for employees',
                hintText: 'e.g. OMAHA1',
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Finish'),
            ),
        ],
      ),
    );
  }
}
