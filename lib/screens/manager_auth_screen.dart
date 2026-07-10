import 'package:flutter/material.dart';

import '../services/store.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/store_message.dart';

/// Manager entry: Google sign-in for returning managers, or self-service
/// company signup for new tenants.
class ManagerAuthScreen extends StatefulWidget {
  const ManagerAuthScreen({super.key});

  @override
  State<ManagerAuthScreen> createState() => _ManagerAuthScreenState();
}

class _ManagerAuthScreenState extends State<ManagerAuthScreen> {
  final _companyName = TextEditingController();
  final _companyCode = TextEditingController();
  final _locationName = TextEditingController();
  final _city = TextEditingController();

  bool _creating = false;
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _companyName.dispose();
    _companyCode.dispose();
    _locationName.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    final err = await Store.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showStoreMessage(context, err, error: true);
  }

  Future<void> _createCompany() async {
    setState(() => _formError = null);
    setState(() => _busy = true);
    final err = await Store.instance.createPendingCompany(
      companyName: _companyName.text,
      companyCode: _companyCode.text,
      locationName: _locationName.text,
      city: _city.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _formError = err);
    }
  }

  void _back() {
    Store.instance.signOutManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AnimatedBuilder(
                animation: Store.instance,
                builder: (context, _) {
                  final appUser = Store.instance.appUser;
                  final signedIn = appUser != null;
                  final showSignupForm =
                      _creating && signedIn && appUser.role == null;
                  final showNotInvited =
                      signedIn && appUser.role == null && !_creating;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const BrandHeader(),
                      const SizedBox(height: 24),
                      if (showSignupForm)
                        _signupForm(appUser.email)
                      else if (showNotInvited)
                        _notInvited(appUser.email)
                      else if (_creating)
                        _createStep()
                      else
                        _signInStep(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back to company code'),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Manager sign in', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'Sign in with the Google account your company invited. '
            'After your company is approved, you\'ll land on the Team Dashboard.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 18),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            _googleButton(),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => setState(() => _creating = true),
              child: const Text('Create a new company'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _createStep() {
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create your company', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'New car wash? Continue with Google, submit your company for approval, '
            'then wait for platform approval. You\'ll be the first manager.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 18),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            _googleButton(),
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

  Widget _notInvited(String email) {
    final claimErr = Store.instance.managerClaimError;
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Not a manager yet', style: TextStyles.subheading),
          const SizedBox(height: 8),
          Text(
            'This Google account isn’t a manager yet. Ask a company manager to add '
            '$email under Managers, then sign in again.\n\n'
            'Or choose Create a new company if you’re starting a new business.',
            style: TextStyles.caption,
          ),
          if (claimErr != null) ...[
            const SizedBox(height: 8),
            Text(claimErr,
                style: TextStyles.caption.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _creating = true),
            child: const Text('Create a new company'),
          ),
          TextButton(
            onPressed: () => Store.instance.signOutManager(),
            child: const Text('Use a different Google account'),
          ),
        ],
      ),
    );
  }

  Widget _signupForm(String email) {
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Finish signup', style: TextStyles.subheading),
          const SizedBox(height: 6),
          Text('Signed in as $email', style: TextStyles.caption),
          const SizedBox(height: 16),
          TextField(
            controller: _companyName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Company name',
              hintText: 'e.g. Sparkle Auto Wash',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyCode,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Company code',
              hintText: 'e.g. SPARKLE',
              errorText: _formError,
              helperText: 'Employees will use this to sign in (4+ characters)',
            ),
            onChanged: (_) {
              if (_formError != null) setState(() => _formError = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'First location name',
              hintText: 'e.g. Omaha — 144th St',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City (optional)',
            ),
          ),
          const SizedBox(height: 18),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _createCompany,
              child: const Text('Submit for approval'),
            ),
        ],
      ),
    );
  }

  Widget _googleButton() {
    return OutlinedButton.icon(
      onPressed: _googleSignIn,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.hairline),
      ),
      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
      label: const Text('Continue with Google'),
    );
  }
}
