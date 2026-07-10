import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/profile.dart';
import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/staff_request_logic.dart';
import '../utils/staff_request_seen_prefs.dart';
import '../utils/ui_density.dart';
import '../models/staff_request.dart';
import '../widgets/challenge_card.dart';
import '../widgets/google_review_qr.dart';
import '../widgets/profile_menu.dart';
import '../widgets/store_message.dart';
import '../widgets/tally_row.dart';
import '../widgets/ui_kit.dart';
import 'employee_requests_screen.dart';
import 'tips_screen.dart';
import 'reports_screen.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// The employee's digital scorecard — a 1:1 of the physical tally card.
class ScorecardScreen extends StatefulWidget {
  const ScorecardScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  final _baGoal = TextEditingController(text: '40');
  final Map<String, int> _counts = {for (final i in kLineItems) i.id: 0};
  int _talkedTo = 0;

  // Last values persisted to the database, used to detect unsaved changes.
  final Map<String, int> _savedCounts = {for (final i in kLineItems) i.id: 0};
  double _savedBaGoal = 40;
  int _savedTalkedTo = 0;

  bool _saving = false;
  bool _hasSavedBefore = false;
  bool _showSavedFlash = false;
  bool _seeded = false;
  bool _hadDraft = false;
  Timer? _flashTimer;
  UiDensity _density = UiDensity.comfortable;
  int _unseenAssignments = 0;

  /// Deterministic id so every Save during a shift updates the *same* running
  /// record for this employee on this day (instead of creating duplicates).
  String get _todayId {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final slug = widget.profile.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'shift-${d.year}${two(d.month)}${two(d.day)}-$slug';
  }

  @override
  void initState() {
    super.initState();
    _hadDraft = _restoreDraft();
    _seed();
    if (!_seeded) Store.instance.addListener(_seedWhenReady);
    Store.instance.addListener(_refreshUnseenAssignments);
    UiDensityPrefs.load().then((p) {
      if (!mounted) return;
      setState(() => _density = p.density);
    });
    _refreshUnseenAssignments();
  }

  Future<void> _refreshUnseenAssignments() async {
    final loc = Store.instance.activeLocationId ?? '';
    final key = staffRequestProfileKey(widget.profile.name);
    final seen = await StaffRequestSeenPrefs.load(
      locationId: loc,
      profileKey: key,
    );
    final assigned = Store.instance.staffRequests.where((r) {
      if (r.status != StaffRequestStatus.assigned || r.isPersonal) return false;
      final aKey = r.assigneeProfileKey ?? '';
      if (aKey.isNotEmpty) return aKey == key;
      return r.employeeName.trim().toLowerCase() == key;
    });
    final n = assigned.where((r) => !seen.contains(r.id)).length;
    if (!mounted) return;
    if (n != _unseenAssignments) {
      setState(() => _unseenAssignments = n);
    }
  }

  bool _restoreDraft() {
    final draft = Store.instance.loadDraft(widget.profile.name);
    if (draft == null) return false;
    final counts = (draft['counts'] as Map?) ?? {};
    for (final entry in counts.entries) {
      final id = entry.key as String;
      if (_counts.containsKey(id)) {
        _counts[id] = (entry.value as num).toInt();
      }
    }
    final goal = draft['baGoal'];
    if (goal != null) {
      _baGoal.text = _fmtGoal((goal as num).toDouble());
    }
    _talkedTo = (draft['talkedTo'] as num?)?.toInt() ?? 0;
    return true;
  }

  static String _fmtGoal(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Submission? _todayRecord() {
    for (final s in Store.instance.submissions) {
      if (s.id == _todayId) return s;
    }
    return null;
  }

  /// Seeds the "saved" baseline (and, if there's no local draft, the on-screen
  /// numbers) from today's existing record so the running total continues.
  void _seed() {
    final rec = _todayRecord();
    if (rec != null) {
      for (final i in kLineItems) {
        _savedCounts[i.id] = rec.countOf(i.id);
      }
      _savedBaGoal = rec.baGoal;
      _savedTalkedTo = rec.talkedTo;
      _hasSavedBefore = true;
      if (!_hadDraft) {
        for (final i in kLineItems) {
          _counts[i.id] = rec.countOf(i.id);
        }
        _baGoal.text = _fmtGoal(rec.baGoal);
        _talkedTo = rec.talkedTo;
      }
      _seeded = true;
    } else if (!Store.instance.submissionsLoading) {
      // No record and data has loaded: baseline is the (empty) defaults.
      _seeded = true;
    }
  }

  void _seedWhenReady() {
    if (_seeded) {
      Store.instance.removeListener(_seedWhenReady);
      return;
    }
    setState(_seed);
    if (_seeded) Store.instance.removeListener(_seedWhenReady);
  }

  void _persistDraft() {
    Store.instance.saveDraft(
      widget.profile.name,
      counts: Map.of(_counts),
      baGoal: double.tryParse(_baGoal.text.trim()) ?? 0,
      talkedTo: _talkedTo,
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    Store.instance.removeListener(_seedWhenReady);
    Store.instance.removeListener(_refreshUnseenAssignments);
    _baGoal.dispose();
    super.dispose();
  }

  bool get _dirty {
    final goal = double.tryParse(_baGoal.text.trim()) ?? 0;
    if (goal != _savedBaGoal) return true;
    if (_talkedTo != _savedTalkedTo) return true;
    for (final i in kLineItems) {
      if ((_counts[i.id] ?? 0) != (_savedCounts[i.id] ?? 0)) return true;
    }
    return false;
  }

  Submission get _live => Submission(
        id: 'live',
        employeeName: widget.profile.name,
        baGoal: double.tryParse(_baGoal.text.trim()) ?? 0,
        counts: Map.of(_counts),
        submittedAt: DateTime.now(),
        talkedTo: _talkedTo,
      );

  bool get _hasAnyTally => _talkedTo > 0 || _counts.values.any((c) => c > 0);

  void _set(String id, int value) {
    setState(() => _counts[id] = value);
    _persistDraft();
  }

  Future<void> _resetCard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear scorecard?'),
        content: const Text('This resets every tally back to zero.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        for (final i in kLineItems) {
          _counts[i.id] = 0;
        }
        _talkedTo = 0;
      });
      await Store.instance.clearDraft(widget.profile.name);
    }
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    final goal = double.tryParse(_baGoal.text.trim()) ?? 0;
    final submission = Submission(
      id: _todayId,
      employeeName: widget.profile.name,
      baGoal: goal,
      counts: Map.of(_counts),
      submittedAt: DateTime.now(),
      talkedTo: _talkedTo,
    );
    try {
      await Store.instance.addSubmission(submission);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showStoreMessage(context, 'Could not save. Check your connection.',
          error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      for (final i in kLineItems) {
        _savedCounts[i.id] = _counts[i.id] ?? 0;
      }
      _savedBaGoal = goal;
      _savedTalkedTo = _talkedTo;
      _saving = false;
      _seeded = true;
      _hasSavedBefore = true;
      _showSavedFlash = true;
    });
    _persistDraft();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSavedFlash = false);
    });
  }

  void _shareToBaChat() {
    final s = _live;
    final text = (StringBuffer()
          ..writeln('🚗 WIGGY WASH — Scorecard')
          ..writeln(widget.profile.name)
          ..writeln('')
          ..writeln('Memberships: ${s.totalMemberships}')
          ..writeln('Single washes: ${s.totalSingleWashes}')
          ..writeln('Shop sales: ${s.totalShopSales}')
          ..writeln(
              'BA: ${s.conversionRate.toStringAsFixed(0)}% (goal ${s.baGoal.toStringAsFixed(0)}%)')
          ..writeln('Total revenue: ${_money.format(s.grandTotalRevenue)}'))
        .toString();
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final stepSize = phone
        ? math.max(_density.stepButtonSize, 48.0)
        : _density.stepButtonSize;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scorecard'),
        actions: [
          IconButton(
            tooltip: 'Tips',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const TipsScreen(audience: TipsAudience.employee),
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const GoogleReviewQrButton(),
          IconButton(
            tooltip: 'Clear scorecard',
            onPressed: _hasAnyTally ? _resetCard : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Requests',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmployeeRequestsScreen(),
                ),
              );
              if (mounted) _refreshUnseenAssignments();
            },
            icon: Badge(
              isLabelVisible: _unseenAssignments > 0,
              label: Text('$_unseenAssignments'),
              child: const Icon(Icons.campaign_outlined),
            ),
          ),
          const ProfileAction(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedBuilder(
              animation: Store.instance,
              builder: (context, _) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    _density.pagePadding,
                    _density.pagePadding,
                    _density.pagePadding,
                    120,
                  ),
                  children: [
                    if (Store.instance.challenge != null) ...[
                      const ChallengeCard(),
                      SizedBox(height: _density.sectionGap - 4),
                    ],
                    if (Store.instance.seeAll) ...[
                      SizedBox(height: _density.sectionGap - 4),
                      _TeamButton(),
                    ],
                    SizedBox(height: _density.sectionGap - 4),
                    _HeaderCard(
                      name: widget.profile.name,
                      baController: _baGoal,
                      live: live,
                      onBaChanged: () {
                        setState(() {});
                        _persistDraft();
                      },
                    ),
                    SizedBox(height: _density.sectionGap - 4),
                    _TalkedToCard(
                      value: _talkedTo,
                      onChanged: (v) {
                        setState(() => _talkedTo = v < 0 ? 0 : v);
                        _persistDraft();
                      },
                    ),
                    SizedBox(height: _density.sectionGap - 4),
                    ..._buildSections(stepSize),
                    SizedBox(height: _density.sectionGap),
                    Center(
                      child: TextButton.icon(
                        onPressed: _hasAnyTally ? _shareToBaChat : null,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share to BA chat'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
            color: AppColors.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StickyShiftSummary(live: live, talkedTo: _talkedTo),
                const SizedBox(height: 8),
                _SaveStatus(
                  saving: _saving,
                  dirty: _dirty,
                  showFlash: _showSavedFlash,
                  hasSavedBefore: _hasSavedBefore,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_dirty && !_saving) ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(double stepSize) {
    final widgets = <Widget>[];
    for (final section in Store.instance.enabledSections) {
      widgets.add(SectionPill(section.title));
      for (final item in itemsFor(section)) {
        widgets.add(
          TallyRow(
            item: item,
            count: _counts[item.id] ?? 0,
            onChanged: (v) => _set(item.id, v),
            stepButtonSize: stepSize,
            verticalMargin: _density.tallyVerticalMargin,
          ),
        );
      }
    }
    return widgets;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.baController,
    required this.live,
    required this.onBaChanged,
  });

  final String name;
  final TextEditingController baController;
  final Submission live;
  final VoidCallback onBaChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCORECARD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.navy,
              )),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Name', style: TextStyles.caption),
                    const SizedBox(height: 2),
                    Text(name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BA Goal', style: TextStyles.caption),
                    const SizedBox(height: 2),
                    TextField(
                      controller: baController,
                      onChanged: (_) => onBaChanged(),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BA Actual', style: TextStyles.caption),
                    const SizedBox(height: 2),
                    Builder(builder: (context) {
                      final hasGoal = live.baGoal > 0;
                      final boxColor = hasGoal
                          ? baColor(live.businessAverage, live.baGoal)
                          : AppColors.blue;
                      return Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: boxColor,
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        child: Text(
                          '${live.businessAverage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: hasGoal ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Big tally for cars talked to — the denominator for business average.
class _TalkedToCard extends StatelessWidget {
  const _TalkedToCard({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cars talked to', style: TextStyles.subheading),
                const Text('Counts toward your business average',
                    style: TextStyles.caption),
                const SizedBox(height: 4),
                Text('$value',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    )),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({required this.live});
  final Submission live;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Shift Summary', style: TextStyles.subheading),
          const SizedBox(height: 14),
          _StatRow(label: 'Cars talked to', value: '${live.talkedTo}'),
          _StatRow(label: 'Memberships', value: '${live.totalMemberships}'),
          _StatRow(label: 'Single washes', value: '${live.totalSingleWashes}'),
          _StatRow(label: 'Shop sales', value: '${live.totalShopSales}'),
          _StatRow(
            label: 'Business average (BA)',
            value: '${live.businessAverage.toStringAsFixed(0)}%',
          ),
          _StatRow(label: 'Overall score', value: '${live.overallScore}'),
          const Divider(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Revenue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
              AnimatedCount(
                value: live.grandTotalRevenue,
                format: _money.format,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: Text(_expanded ? 'Collapse' : 'Expand'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _BreakdownDetails(live: live),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The full, line-by-line breakdown of today's tallies, grouped by section.
/// Mirrors the "Full breakdown" that previously lived on the reports page.
class _BreakdownDetails extends StatelessWidget {
  const _BreakdownDetails({required this.live});
  final Submission live;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        for (final section in Store.instance.enabledSections) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(section.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.roseText,
                  )),
            ),
          ),
          for (final item in itemsFor(section))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.label, style: TextStyles.body),
                  Text('${live.countOf(item.id)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      )),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyles.body),
          Text(value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

/// Compact sticky strip — Talked-to · BA% · $ — always visible with Save.
class _StickyShiftSummary extends StatelessWidget {
  const _StickyShiftSummary({required this.live, required this.talkedTo});
  final Submission live;
  final int talkedTo;

  @override
  Widget build(BuildContext context) {
    final ba = live.businessAverage;
    final color = baColor(ba, live.baGoal);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Talked $talkedTo',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.navy,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'BA ${ba.toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _money.format(live.grandTotalRevenue),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline save-state indicator shown just above the Save button. Animates
/// between "Unsaved changes", a brief "Saved to database" flash, and a
/// persistent "Saved" checkmark.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({
    required this.saving,
    required this.dirty,
    required this.showFlash,
    required this.hasSavedBefore,
  });

  final bool saving;
  final bool dirty;
  final bool showFlash;
  final bool hasSavedBefore;

  Widget _row(String key, IconData? icon, String text, Color color,
      {bool spinner = false, bool bold = false}) {
    return Row(
      key: ValueKey(key),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spinner)
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else if (icon != null)
          Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (saving) {
      child = _row('saving', null, 'Saving…', AppColors.textMuted,
          spinner: true);
    } else if (dirty) {
      child = _row('dirty', Icons.cloud_off_rounded, 'Unsaved changes',
          AppColors.warning);
    } else if (showFlash) {
      child = _row('flash', Icons.check_circle_rounded, 'Saved to database',
          AppColors.success,
          bold: true);
    } else if (hasSavedBefore) {
      child = _row('saved', Icons.check_circle_rounded, 'Saved',
          AppColors.success);
    } else {
      child = const SizedBox(key: ValueKey('none'), height: 16);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: child,
    );
  }
}

/// Visible only when the manager enables "see all" — lets employees view the
/// whole team's submissions for today.
class _TeamButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReportsScreen(title: 'Team today'),
        ),
      ),
      icon: const Icon(Icons.groups_rounded),
      label: const Text('View team totals'),
    );
  }
}
