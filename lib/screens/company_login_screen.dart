import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/location.dart';
import '../models/worker.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/ui_density.dart';
import '../widgets/company_header.dart';
import '../widgets/step_indicator.dart';

enum _LoginStep { companyCode, location, name }

/// Landing page — employees enter a company code, pick a location (if needed),
/// then pick their name. Managers use Google sign-in below the card.
class CompanyLoginScreen extends StatefulWidget {
  const CompanyLoginScreen({super.key});

  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  _LoginStep _step = _LoginStep.companyCode;
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _locationQuery = TextEditingController();

  bool _busy = false;
  String? _codeError;
  Company? _company;
  Location? _location;
  Worker? _selected;
  String? _pinError;

  UiDensity get _density => UiDensityController.instance.density;

  @override
  void initState() {
    super.initState();
    UiDensityController.instance.addListener(_onDensityChanged);
    _locationQuery.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyResume());
  }

  Future<void> _applyResume() async {
    final store = Store.instance;
    final resume = store.employeeLoginResume;
    if (resume == EmployeeLoginResume.none) return;
    final companyId = store.activeCompanyId;
    if (companyId == null) return;
    setState(() => _busy = true);
    await store.previewCompany(companyId);
    if (!mounted) return;
    final company = store.activeCompany;
    final locs = store.companyLocations;
    if (company == null) {
      setState(() => _busy = false);
      return;
    }
    if (resume == EmployeeLoginResume.location) {
      setState(() {
        _busy = false;
        _company = company;
        _step = locs.length <= 1 && locs.isNotEmpty
            ? _LoginStep.name
            : _LoginStep.location;
        if (locs.length == 1) {
          _location = locs.first;
          store.previewLocation(locs.first.id);
        }
      });
      store.employeeLoginResume = EmployeeLoginResume.none;
      return;
    }
    // Resume at name step — need an active location.
    final locId = store.activeLocationId;
    Location? loc;
    for (final l in locs) {
      if (l.id == locId) loc = l;
    }
    loc ??= locs.length == 1 ? locs.first : null;
    if (loc == null) {
      setState(() {
        _busy = false;
        _company = company;
        _step = _LoginStep.location;
      });
      store.employeeLoginResume = EmployeeLoginResume.none;
      return;
    }
    store.previewLocation(loc.id);
    setState(() {
      _busy = false;
      _company = company;
      _location = loc;
      _step = _LoginStep.name;
    });
    store.employeeLoginResume = EmployeeLoginResume.none;
  }

  void _onDensityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UiDensityController.instance.removeListener(_onDensityChanged);
    _code.dispose();
    _pin.dispose();
    _locationQuery.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _codeError = null;
    });
    final company = await Store.instance.lookupCompanyCode(_code.text);
    if (!mounted) return;
    if (company == null) {
      setState(() {
        _busy = false;
        _codeError = 'Code not found — check with your manager';
      });
      return;
    }
    switch (company.status) {
      case CompanyStatus.suspended:
        setState(() {
          _busy = false;
          _codeError = 'This company account is suspended. Contact support.';
        });
        return;
      case CompanyStatus.pending:
        setState(() {
          _busy = false;
          _codeError = 'This company isn\'t active yet. Check back soon.';
        });
        return;
      case CompanyStatus.active:
        break;
    }
    await Store.instance.previewCompany(company.id);
    if (!mounted) return;
    final locs = Store.instance.companyLocations;
    setState(() {
      _busy = false;
      _company = company;
      if (locs.length == 1) {
        _location = locs.first;
        Store.instance.previewLocation(locs.first.id);
        _step = _LoginStep.name;
      } else {
        _step = _LoginStep.location;
      }
    });
  }

  void _backToCode() {
    setState(() {
      _step = _LoginStep.companyCode;
      _company = null;
      _location = null;
      _selected = null;
      _pin.clear();
      _pinError = null;
    });
  }

  void _selectLocation(Location loc) {
    Store.instance.previewLocation(loc.id);
    setState(() {
      _location = loc;
      _step = _LoginStep.name;
      _selected = null;
      _pin.clear();
      _pinError = null;
    });
  }

  void _backToLocation() {
    final locs = Store.instance.companyLocations;
    setState(() {
      _selected = null;
      _pin.clear();
      _pinError = null;
      _step = locs.length <= 1 ? _LoginStep.companyCode : _LoginStep.location;
      if (_step == _LoginStep.companyCode) {
        _location = null;
        _company = null;
      }
    });
  }

  Future<void> _startScorecard() async {
    final worker = _selected;
    final loc = _location;
    final company = _company;
    if (worker == null || loc == null || company == null) return;
    if (worker.requiresPin && !worker.verifyPin(_pin.text)) {
      setState(() => _pinError = 'Incorrect entry code');
      return;
    }
    await Store.instance.signInEmployee(
      locationId: loc.id,
      name: worker.name,
      companyId: company.id,
      companyCode: company.companyCode,
    );
  }

  int get _stepNumber => switch (_step) {
        _LoginStep.companyCode => 1,
        _LoginStep.location => 2,
        _LoginStep.name => 3,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_density.pagePadding + 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  CompanyHeader(company: _company),
                  const SizedBox(height: 20),
                  StepIndicator(step: _stepNumber, total: 3),
                  const SizedBox(height: 20),
                  switch (_step) {
                    _LoginStep.companyCode => _buildCodeStep(),
                    _LoginStep.location => _buildLocationStep(),
                    _LoginStep.name => _buildNameStep(),
                  },
                  if (_step == _LoginStep.companyCode) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => Store.instance.openManagerAuth(),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Manager? Sign in with Google'),
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

  Widget _buildCodeStep() {
    return AppCard(
      padding: EdgeInsets.all(_density.loginCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter company code', style: TextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            'Ask your manager for your company\'s code.',
            style: TextStyles.caption,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Company code',
              hintText: 'e.g. WIGGY',
              errorText: _codeError,
            ),
            onSubmitted: (_) {
              if (!_busy) _submitCode();
            },
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _busy ? null : _submitCode,
            child: _busy
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

  Widget _buildLocationStep() {
    final locs = Store.instance.companyLocations;
    final q = _locationQuery.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? locs
        : locs
            .where((l) =>
                l.name.toLowerCase().contains(q) ||
                l.city.toLowerCase().contains(q) ||
                l.displayName.toLowerCase().contains(q))
            .toList();
    final recentIds = Store.instance.loadRecentLocationIds();
    final recent = <Location>[];
    for (final id in recentIds) {
      for (final l in locs) {
        if (l.id == id) {
          recent.add(l);
          break;
        }
      }
    }
    final showRecent = q.isEmpty && recent.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _backToCode,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              const Expanded(
                child: Text('Pick your location', style: TextStyles.subheading),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Which site are you working at today?',
              style: TextStyles.caption),
          const SizedBox(height: 12),
          if (locs.length > 5) ...[
            TextField(
              controller: _locationQuery,
              decoration: const InputDecoration(
                labelText: 'Search sites',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (locs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No locations set up yet. Ask your manager.',
                style: TextStyles.caption,
              ),
            )
          else ...[
            if (showRecent) ...[
              const Text('Recent', style: TextStyles.caption),
              const SizedBox(height: 6),
              for (final loc in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LocationTile(
                    location: loc,
                    onTap: () => _selectLocation(loc),
                  ),
                ),
              const SizedBox(height: 4),
              const Text('All sites', style: TextStyles.caption),
              const SizedBox(height: 6),
            ],
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No sites match that search.',
                    style: TextStyles.caption),
              )
            else
              ...filtered.map((loc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LocationTile(
                      location: loc,
                      onTap: () => _selectLocation(loc),
                    ),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _buildNameStep() {
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
                    onPressed: _backToLocation,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      _location?.displayName ?? 'Select your name',
                      style: TextStyles.subheading,
                    ),
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
                    child: _NameTile(
                      worker: w,
                      selected: _selected?.id == w.id,
                      onTap: () => setState(() {
                        _selected = w;
                        _pin.clear();
                        _pinError = null;
                      }),
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
                onPressed: _selected == null ? null : _startScorecard,
                child: const Text('Start scorecard'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location, required this.onTap});
  final Location location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueSoft,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.navy.withValues(alpha: 0.12),
                child: const Icon(Icons.storefront_rounded,
                    color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({
    required this.worker,
    required this.selected,
    required this.onTap,
  });

  final Worker worker;
  final bool selected;
  final VoidCallback onTap;

  String get _initials {
    final parts = worker.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : AppColors.blueSoft,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    selected ? Colors.white24 : AppColors.navy.withValues(alpha: 0.12),
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.navy,
                      ),
                    ),
                    if (worker.requiresPin)
                      Text(
                        'Code required',
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white70 : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
