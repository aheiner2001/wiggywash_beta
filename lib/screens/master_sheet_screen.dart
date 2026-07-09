import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/csv.dart';
import '../utils/exporter.dart';
import '../utils/master_sheet_stats.dart';
import '../utils/sheet_column.dart';
import '../utils/sheet_row_tools.dart';
import '../utils/sheet_tools_prefs.dart';
import '../utils/trends_visual_prefs.dart';
import '../utils/xlsx.dart';
import '../widgets/master_sheet_trends.dart';
import '../widgets/profile_menu.dart';
import '../widgets/sheet_tools_bar.dart';
import '../widgets/store_message.dart';
import '../widgets/submission_editor.dart';
import '../widgets/ui_kit.dart';

enum MasterSheetLayout { vertical, horizontal }

const _kMasterSheetLayout = 'ww_master_sheet_layout';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _dayLabel = DateFormat('EEE, MMM d');
final _monthLabel = DateFormat('MMMM yyyy');
final _shortDate = DateFormat('M/d');

enum _View { team, member, month }

enum _ExportFormat { xlsx, csv, clipboard }

/// Builds grid rows for display and export from approved submissions.
({
  List<MasterSheetRow> rows,
  Submission totals,
  String title,
  String rangeLabel,
  bool firstColIsDate,
}) _buildMasterSheetRows({
  required List<Submission> scope,
  required _View view,
  required DateTime anchor,
  required String? member,
  required Submission Function(String, List<Submission>, DateTime) aggregate,
}) {
  final isDaily = view == _View.member;
  final rows = <MasterSheetRow>[];
  if (isDaily) {
    final byDay = [...scope]..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    for (final s in byDay) {
      rows.add(MasterSheetRow(label: _shortDate.format(s.submittedAt), submission: s));
    }
  } else {
    final byName = <String, List<Submission>>{};
    for (final s in scope) {
      byName.putIfAbsent(s.employeeName, () => []).add(s);
    }
    final names = byName.keys.toList()..sort();
    for (final n in names) {
      rows.add(MasterSheetRow(
        label: n,
        submission: aggregate(n, byName[n]!, anchor),
      ));
    }
  }
  final totals = aggregate('TOTALS', scope, anchor);
  final title = isDaily
      ? '${member ?? ''} · ${_monthLabel.format(anchor)}'
      : (view == _View.team
          ? _dayLabel.format(anchor)
          : _monthLabel.format(anchor));
  final rangeLabel = title;
  return (
    rows: rows,
    totals: totals,
    title: Store.instance.activeCompany?.name ??
        Store.instance.activeLocation?.name ??
        'Master Sheet',
    rangeLabel: rangeLabel,
    firstColIsDate: isDaily,
  );
}

/// Manager "BA Master Doc" — approved scorecards rolled into a clean,
/// spreadsheet-style grid with a pending-approval sidebar.
class MasterSheetScreen extends StatefulWidget {
  const MasterSheetScreen({super.key});

  @override
  State<MasterSheetScreen> createState() => _MasterSheetScreenState();
}

class _MasterSheetScreenState extends State<MasterSheetScreen> {
  _View _view = _View.team;
  DateTime _anchor = DateTime.now();
  String? _member;
  bool _sidebarOpen = true;
  DateTimeRange? _customRange;
  MasterSheetLayout _layout = MasterSheetLayout.vertical;
  SheetToolsPrefs _sheetPrefs = SheetToolsPrefs.defaults();
  Set<String>? _selectedEmployees; // session-only
  TrendsVisualPrefs _trendsPrefs = TrendsVisualPrefs.defaults();

  @override
  void initState() {
    super.initState();
    _loadLayoutPref();
    _loadSheetToolsPref();
    _loadTrendsPrefs();
  }

  Future<void> _loadLayoutPref() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMasterSheetLayout);
    if (!mounted) return;
    if (raw == MasterSheetLayout.horizontal.name) {
      setState(() => _layout = MasterSheetLayout.horizontal);
    }
  }

  Future<void> _loadSheetToolsPref() async {
    final p = await SheetToolsPrefs.load();
    if (!mounted) return;
    setState(() => _sheetPrefs = p);
  }

  Future<void> _loadTrendsPrefs() async {
    final p = await TrendsVisualPrefs.load();
    if (!mounted) return;
    setState(() => _trendsPrefs = p);
  }

  Future<void> _setSheetPrefs(SheetToolsPrefs prefs) async {
    setState(() => _sheetPrefs = prefs);
    await SheetToolsPrefs.save(prefs);
  }

  Future<void> _setTrendsPrefs(TrendsVisualPrefs prefs) async {
    setState(() => _trendsPrefs = prefs);
    await TrendsVisualPrefs.save(prefs);
  }

  Future<void> _setLayout(MasterSheetLayout layout) async {
    setState(() => _layout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMasterSheetLayout, layout.name);
  }

  (DateTime, DateTime) _statsRange() {
    if (_customRange != null) {
      return (
        DateTime(_customRange!.start.year, _customRange!.start.month,
            _customRange!.start.day),
        DateTime(_customRange!.end.year, _customRange!.end.month,
                _customRange!.end.day)
            .add(const Duration(days: 1)),
      );
    }
    if (_view == _View.team) {
      final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
      return (d, d.add(const Duration(days: 1)));
    }
    final start = DateTime(_anchor.year, _anchor.month, 1);
    final end = DateTime(_anchor.year, _anchor.month + 1, 1);
    return (start, end);
  }

  MasterSheetStats get _stats {
    final range = _statsRange();
    var list = Store.instance.approvedSubmissions;
    if (_view == _View.member && _member != null) {
      list = list.where((s) => s.employeeName == _member).toList();
    }
    return buildMasterSheetStats(
      submissions: list,
      rangeStart: range.$1,
      rangeEndExclusive: range.$2,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  void _shift(int dir) {
    setState(() {
      if (_view == _View.team) {
        _anchor = _anchor.add(Duration(days: dir));
      } else {
        _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
      }
    });
  }

  /// Approved scorecards visible in the current view's time window.
  List<Submission> get _scope {
    final approved = Store.instance.approvedSubmissions;
    if (_customRange != null) {
      final end = _customRange!.end.add(const Duration(days: 1));
      return approved
          .where((s) =>
              !s.submittedAt.isBefore(_customRange!.start) &&
              s.submittedAt.isBefore(end))
          .toList();
    }
    switch (_view) {
      case _View.team:
        return approved.where((s) => _sameDay(s.submittedAt, _anchor)).toList();
      case _View.month:
        return approved
            .where((s) => _sameMonth(s.submittedAt, _anchor))
            .toList();
      case _View.member:
        return approved
            .where((s) =>
                _sameMonth(s.submittedAt, _anchor) &&
                _member != null &&
                s.employeeName.toLowerCase() == _member!.toLowerCase())
            .toList();
    }
  }

  Submission _aggregate(String name, List<Submission> subs, DateTime when) {
    final counts = <String, int>{};
    var talked = 0;
    var goalSum = 0.0;
    var goalN = 0;
    for (final s in subs) {
      for (final e in s.counts.entries) {
        counts[e.key] = (counts[e.key] ?? 0) + e.value;
      }
      talked += s.talkedTo;
      if (s.baGoal > 0) {
        goalSum += s.baGoal;
        goalN++;
      }
    }
    return Submission(
      id: name,
      employeeName: name,
      baGoal: goalN > 0 ? goalSum / goalN : 0,
      counts: counts,
      submittedAt: when,
      talkedTo: talked,
      approved: true,
    );
  }

  String get _viewLabel => _customRange != null
      ? 'Custom range'
      : switch (_view) {
          _View.team => 'Team',
          _View.member => 'Member',
          _View.month => 'Month',
        };

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
    );
    if (picked != null) setState(() => _customRange = picked);
  }

  Future<void> _export(_ExportFormat format) async {
    final scope = _scope;
    if (scope.isEmpty) {
      showStoreMessage(context, 'Nothing to export here yet.', error: true);
      return;
    }
    final built = _buildMasterSheetRows(
      scope: scope,
      view: _view,
      anchor: _anchor,
      member: _member,
      aggregate: _aggregate,
    );
    final slug = (built.title)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  try {
      switch (format) {
        case _ExportFormat.xlsx:
          final bytes = buildMasterSheetXlsx(
            rows: built.rows,
            totals: built.totals,
            title: built.title,
            viewLabel: '${built.rangeLabel} · $_viewLabel',
            firstColIsDate: built.firstColIsDate,
          );
          await exportXlsx('$slug-${_view.name}.xlsx', bytes);
        case _ExportFormat.csv:
          await exportCsv('$slug-${_view.name}.csv', submissionsToCsv(scope));
        case _ExportFormat.clipboard:
          await Clipboard.setData(ClipboardData(
            text: masterSheetToTsv(
              rows: built.rows,
              totals: built.totals,
              title: built.title,
              viewLabel: '${built.rangeLabel} · $_viewLabel',
              firstColIsDate: built.firstColIsDate,
            ),
          ));
          if (mounted) showStoreMessage(context, 'Copied to clipboard');
      }
    } catch (e) {
      if (mounted) showStoreMessage(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _addManual() async {
    final result = await showSubmissionEditor(context, isNew: true);
    if (result == null) return;
    await Store.instance.addSubmission(result.copyWith(approved: true));
    if (mounted) showStoreMessage(context, 'Added ${result.employeeName}');
  }

  void _drillToMember(String name) {
    setState(() {
      _member = name;
      _view = _View.member;
    });
  }

  Future<void> _editApproved(Submission s) async {
    final result = await showSubmissionEditor(context, existing: s);
    if (result == null) return;
    final err = await Store.instance.updateSubmission(
      s.id,
      counts: result.counts,
      baGoal: result.baGoal,
      talkedTo: result.talkedTo,
    );
    if (mounted && err != null) showStoreMessage(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Sheet'),
        actions: [
          IconButton(
            tooltip: 'Add scorecard',
            onPressed: _addManual,
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<_ExportFormat>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_rounded),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ExportFormat.xlsx,
                child: Text('Excel (.xlsx)'),
              ),
              PopupMenuItem(
                value: _ExportFormat.csv,
                child: Text('CSV (.csv)'),
              ),
              PopupMenuItem(
                value: _ExportFormat.clipboard,
                child: Text('Copy to clipboard'),
              ),
            ],
          ),
          IconButton(
            tooltip: _customRange == null ? 'Custom date range' : 'Clear range',
            onPressed: () {
              if (_customRange != null) {
                setState(() => _customRange = null);
              } else {
                _pickCustomRange();
              }
            },
            icon: Icon(
              _customRange == null
                  ? Icons.date_range_rounded
                  : Icons.clear_rounded,
            ),
          ),
          IconButton(
            tooltip: _layout == MasterSheetLayout.vertical
                ? 'Switch to side-by-side layout'
                : 'Switch to stacked layout',
            onPressed: () => _setLayout(
              _layout == MasterSheetLayout.vertical
                  ? MasterSheetLayout.horizontal
                  : MasterSheetLayout.vertical,
            ),
            icon: Icon(
              _layout == MasterSheetLayout.vertical
                  ? Icons.view_agenda_outlined
                  : Icons.view_column_outlined,
            ),
          ),
          const ProfileAction(),
        ],
      ),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final pendingCount = Store.instance.pendingSubmissions.length;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final main = _MainPanel(
                view: _view,
                anchor: _anchor,
                member: _member,
                scope: _scope,
                stats: _stats,
                layout: _layout,
                sheetPrefs: _sheetPrefs,
                selectedEmployees: _selectedEmployees,
                onSheetPrefs: _setSheetPrefs,
                onSelectedEmployees: (s) =>
                    setState(() => _selectedEmployees = s),
                trendsPrefs: _trendsPrefs,
                onTrendsPrefs: _setTrendsPrefs,
                onView: (v) => setState(() => _view = v),
                onShift: _shift,
                onMember: (m) => setState(() => _member = m),
                onDrill: _drillToMember,
                onEdit: _editApproved,
                aggregate: _aggregate,
                viewLabel: _viewLabel,
                customRange: _customRange,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: main),
                    const VerticalDivider(width: 1),
                    if (_sidebarOpen)
                      SizedBox(
                        width: 320,
                        child: _PendingSidebar(
                          onChanged: () => setState(() {}),
                          onCollapse: () =>
                              setState(() => _sidebarOpen = false),
                        ),
                      )
                    else
                      _CollapsedRail(
                        count: pendingCount,
                        onExpand: () => setState(() => _sidebarOpen = true),
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  _PendingBanner(onChanged: () => setState(() {})),
                  Expanded(child: main),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MainPanel extends StatelessWidget {
  const _MainPanel({
    required this.view,
    required this.anchor,
    required this.member,
    required this.scope,
    required this.stats,
    required this.layout,
    required this.sheetPrefs,
    required this.selectedEmployees,
    required this.onSheetPrefs,
    required this.onSelectedEmployees,
    required this.trendsPrefs,
    required this.onTrendsPrefs,
    required this.onView,
    required this.onShift,
    required this.onMember,
    required this.onDrill,
    required this.onEdit,
    required this.aggregate,
    required this.viewLabel,
    this.customRange,
  });

  final _View view;
  final DateTime anchor;
  final String? member;
  final List<Submission> scope;
  final MasterSheetStats stats;
  final MasterSheetLayout layout;
  final SheetToolsPrefs sheetPrefs;
  final Set<String>? selectedEmployees;
  final ValueChanged<SheetToolsPrefs> onSheetPrefs;
  final ValueChanged<Set<String>?> onSelectedEmployees;
  final TrendsVisualPrefs trendsPrefs;
  final ValueChanged<TrendsVisualPrefs> onTrendsPrefs;
  final ValueChanged<_View> onView;
  final ValueChanged<int> onShift;
  final ValueChanged<String?> onMember;
  final ValueChanged<String> onDrill;
  final ValueChanged<Submission> onEdit;
  final Submission Function(String, List<Submission>, DateTime) aggregate;
  final String viewLabel;
  final DateTimeRange? customRange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<_View>(
            segments: const [
              ButtonSegment(value: _View.team, label: Text('Team')),
              ButtonSegment(value: _View.member, label: Text('Member')),
              ButtonSegment(value: _View.month, label: Text('Month')),
            ],
            selected: {view},
            onSelectionChanged: (s) => onView(s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  view == _View.team
                      ? _dayLabel.format(anchor)
                      : _monthLabel.format(anchor),
                  textAlign: TextAlign.center,
                  style: TextStyles.subheading,
                ),
              ),
              IconButton(
                onPressed: () => onShift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        if (view == _View.member)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: DropdownButtonFormField<String>(
              initialValue: member,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Team member',
                isDense: true,
              ),
              items: [
                for (final w in Store.instance.workers)
                  DropdownMenuItem(value: w.name, child: Text(w.name)),
              ],
              onChanged: onMember,
            ),
          ),
        const Divider(height: 1),
        Expanded(child: _buildTrendsAndTable(context)),
      ],
    );
  }

  Future<void> _openTrendsVisuals(BuildContext context) async {
    var local = trendsPrefs;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                void update(TrendsVisualPrefs next) {
                  setLocal(() => local = next);
                  onTrendsPrefs(next);
                }

                Widget check(
                    String label, bool value, ValueChanged<bool> onChanged) {
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(label),
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Visuals', style: TextStyles.subheading),
                    const SizedBox(height: 8),
                    check('Summary chips', local.showSummary, (v) {
                      update(local.copyWith(showSummary: v));
                    }),
                    check('Revenue over time', local.showRevenueOverTime, (v) {
                      update(local.copyWith(showRevenueOverTime: v));
                    }),
                    check('By employee', local.showByEmployee, (v) {
                      update(local.copyWith(showByEmployee: v));
                    }),
                    check('BA % by employee', local.showBaByEmployee, (v) {
                      update(local.copyWith(showBaByEmployee: v));
                    }),
                    check('Memberships vs singles', local.showMembershipMix,
                        (v) {
                      update(local.copyWith(showMembershipMix: v));
                    }),
                    const Divider(),
                    const Text('Trends panel', style: TextStyles.caption),
                    for (final mode in TrendsPanelMode.values)
                      ListTile(
                        dense: true,
                        title: Text(switch (mode) {
                          TrendsPanelMode.expanded => 'Expanded',
                          TrendsPanelMode.chipsOnly => 'Chips only',
                          TrendsPanelMode.hidden => 'Hidden',
                        }),
                        trailing: local.panelMode == mode
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.navy)
                            : null,
                        onTap: () =>
                            update(local.copyWith(panelMode: mode)),
                      ),
                    TextButton(
                      onPressed: () => update(TrendsVisualPrefs.defaults()),
                      child: const Text('Show all / Reset'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendsAndTable(BuildContext context) {
    final hidden = trendsPrefs.panelMode == TrendsPanelMode.hidden;
    final trends = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hidden)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onTrendsPrefs(
                  trendsPrefs.copyWith(panelMode: TrendsPanelMode.expanded),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Trends (hidden) · Show'),
              ),
            )
          else ...[
            Row(
              children: [
                const Expanded(
                    child: Text('Trends', style: TextStyles.subheading)),
                IconButton(
                  tooltip: 'Visuals',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _openTrendsVisuals(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MasterSheetTrends(stats: stats, prefs: trendsPrefs),
          ],
        ],
      ),
    );
    final table = _buildGrid(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final sideBySide =
            layout == MasterSheetLayout.horizontal && wide;
        if (!sideBySide) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              trends,
              const SizedBox(height: 16),
              SizedBox(
                height: 420,
                child: table,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: trends,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: table),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (view == _View.member && member == null) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Pick a team member',
        message: 'Choose a name above to see their daily breakdown.',
      );
    }
    if (scope.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_on_rounded,
        title: 'No approved scorecards',
        message: 'Approve scorecards from the panel to populate the sheet.',
      );
    }

    final isDaily = view == _View.member;
    final built = _buildMasterSheetRows(
      scope: scope,
      view: view,
      anchor: anchor,
      member: member,
      aggregate: aggregate,
    );
    final visibleRows = applySheetRowTools(
      rows: built.rows,
      prefs: sheetPrefs,
      selectedEmployees: selectedEmployees,
      firstColIsDate: built.firstColIsDate,
    );
    final totals = totalsFromVisibleRows(
      visible: visibleRows,
      anchor: anchor,
      aggregate: aggregate,
    );
    final topScore = visibleRows.isEmpty
        ? 0
        : visibleRows
            .map((r) => r.submission.overallScore)
            .reduce((a, b) => a > b ? a : b);
    final title = built.rangeLabel;
    final filterCount = activeFilterCount(
      prefs: sheetPrefs,
      selectedEmployees: selectedEmployees,
      firstColIsDate: built.firstColIsDate,
    );
    final employeeNames = {
      for (final s in scope) s.employeeName,
    }.toList()
      ..sort();

    void clearFilters() {
      onSelectedEmployees(null);
      onSheetPrefs(sheetPrefs.copyWith(
        clearMinBa: true,
        clearMinRevenue: true,
      ));
    }

    _SpreadsheetTable table({
      void Function(Submission)? onTap,
      _TablePart part = _TablePart.all,
      _TablePane pane = _TablePane.full,
    }) =>
        _SpreadsheetTable(
          rows: visibleRows.map((r) => (r.label, r.submission)).toList(),
          totals: totals,
          topScore: topScore,
          firstColIsDate: isDaily,
          onTapRow: onTap,
          part: part,
          pane: pane,
          hiddenColumnIds: sheetPrefs.hiddenColumnIds,
          density: sheetPrefs.density,
        );

    final rangeText = customRange != null
        ? '${_shortDate.format(customRange!.start)} – ${_shortDate.format(customRange!.end)}'
        : built.rangeLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: SheetToolsBar(
            prefs: sheetPrefs,
            onPrefsChanged: onSheetPrefs,
            employeeNames: employeeNames,
            selectedEmployees: selectedEmployees,
            onSelectedEmployeesChanged: onSelectedEmployees,
            showEmployeeFilter: view == _View.team,
            activeFilterCount: filterCount,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Text(
            'Showing ${visibleRows.length} of ${built.rows.length} rows · $rangeText · $viewLabel',
            style: TextStyles.caption,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isDaily
                      ? 'Tap a date to edit'
                      : 'Tap a name to open their days',
                  style: TextStyles.caption,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _FullscreenSheet(title: title, table: table()),
                  ),
                ),
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Expand'),
              ),
            ],
          ),
        ),
        if (visibleRows.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No rows match filters',
                      style: TextStyles.subheading),
                  const SizedBox(height: 8),
                  TextButton(onPressed: clearFilters, child: const Text('Clear')),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _FrozenSheetScroller(
              headerFrozen:
                  table(part: _TablePart.header, pane: _TablePane.frozen),
              headerMetrics:
                  table(part: _TablePart.header, pane: _TablePane.metrics),
              bodyFrozen: table(
                part: _TablePart.body,
                pane: _TablePane.frozen,
                onTap: (s) => isDaily ? onEdit(s) : onDrill(s.employeeName),
              ),
              bodyMetrics: table(
                part: _TablePart.body,
                pane: _TablePane.metrics,
                onTap: (s) => isDaily ? onEdit(s) : onDrill(s.employeeName),
              ),
            ),
          ),
      ],
    );
  }
}

/// Linked freeze-pane scroller: sticky first column + synced header/body.
class _FrozenSheetScroller extends StatefulWidget {
  const _FrozenSheetScroller({
    required this.headerFrozen,
    required this.headerMetrics,
    required this.bodyFrozen,
    required this.bodyMetrics,
  });

  final Widget headerFrozen;
  final Widget headerMetrics;
  final Widget bodyFrozen;
  final Widget bodyMetrics;

  @override
  State<_FrozenSheetScroller> createState() => _FrozenSheetScrollerState();
}

class _FrozenSheetScrollerState extends State<_FrozenSheetScroller> {
  final _hHeader = ScrollController();
  final _hBody = ScrollController();
  final _vFrozen = ScrollController();
  final _vBody = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _hBody.addListener(() => _syncH(_hBody, _hHeader));
    _hHeader.addListener(() => _syncH(_hHeader, _hBody));
    _vBody.addListener(() => _syncV(_vBody, _vFrozen));
    _vFrozen.addListener(() => _syncV(_vFrozen, _vBody));
  }

  void _syncH(ScrollController from, ScrollController to) {
    if (_syncingH || !to.hasClients) return;
    _syncingH = true;
    to.jumpTo(from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    ));
    _syncingH = false;
  }

  void _syncV(ScrollController from, ScrollController to) {
    if (_syncingV || !to.hasClients) return;
    _syncingV = true;
    to.jumpTo(from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    ));
    _syncingV = false;
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    _vFrozen.dispose();
    _vBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.headerFrozen,
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _vFrozen,
                    child: widget.bodyFrozen,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Scrollbar(
                  controller: _hHeader,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _hHeader,
                    scrollDirection: Axis.horizontal,
                    child: widget.headerMetrics,
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vBody,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _vBody,
                      child: SingleChildScrollView(
                        controller: _hBody,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 24),
                        child: widget.bodyMetrics,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TablePart { all, header, body }

enum _TablePane { full, frozen, metrics }

/// Clean spreadsheet grid (à la the BA MASTER DOC): fixed columns, gridlines,
/// rotated headers, a point-value row, color-coded BA, and a totals row.
class _SpreadsheetTable extends StatefulWidget {
  const _SpreadsheetTable({
    required this.rows,
    required this.totals,
    required this.topScore,
    required this.firstColIsDate,
    this.onTapRow,
    this.part = _TablePart.all,
    this.pane = _TablePane.full,
    this.hiddenColumnIds = const {},
    this.density = SheetDensity.comfortable,
  });

  final List<(String, Submission)> rows;
  final Submission totals;
  final int topScore;
  final bool firstColIsDate;
  final void Function(Submission)? onTapRow;
  final _TablePart part;
  final _TablePane pane;
  final Set<String> hiddenColumnIds;
  final SheetDensity density;

  @override
  State<_SpreadsheetTable> createState() => _SpreadsheetTableState();
}

class _SpreadsheetTableState extends State<_SpreadsheetTable> {
  String? _hoveredLabel;

  static const _headerBg = Color(0xFFF4F6FA);
  static const _headerFg = Color(0xFF74808F);
  static const _gridColor = Color(0xFFE2E7EF);
  static const _zebra = Color(0xFFFAFBFC);

  bool _vis(String id) => !widget.hiddenColumnIds.contains(id);

  double get _rowH => switch (widget.density) {
        SheetDensity.comfortable => 40,
        SheetDensity.compact => 32,
        SheetDensity.dense => 26,
      };

  double get _headerH => switch (widget.density) {
        SheetDensity.comfortable => 104,
        SheetDensity.compact => 92,
        SheetDensity.dense => 80,
      };

  double get _bodyFont => switch (widget.density) {
        SheetDensity.comfortable => 12.5,
        SheetDensity.compact => 12,
        SheetDensity.dense => 11,
      };

  @override
  Widget build(BuildContext context) {
    final items = kLineItems;
    final metricIds = <String>[
      if (_vis(SheetColumnId.talked)) SheetColumnId.talked,
      for (final i in items)
        if (_vis(SheetColumnId.lineItem(i.id))) SheetColumnId.lineItem(i.id),
      if (_vis(SheetColumnId.vip)) SheetColumnId.vip,
      if (_vis(SheetColumnId.aboveEco)) SheetColumnId.aboveEco,
      if (_vis(SheetColumnId.ba)) SheetColumnId.ba,
      if (_vis(SheetColumnId.score)) SheetColumnId.score,
      if (_vis(SheetColumnId.revenue)) SheetColumnId.revenue,
    ];

    double metricWidth(String id) => id == SheetColumnId.revenue
        ? 82
        : id == SheetColumnId.score
            ? 58
            : id == SheetColumnId.ba
                ? 54
                : 50;

    final colWidths = <int, TableColumnWidth>{};
    switch (widget.pane) {
      case _TablePane.frozen:
        colWidths[0] = const FixedColumnWidth(116);
      case _TablePane.metrics:
        for (var c = 0; c < metricIds.length; c++) {
          colWidths[c] = FixedColumnWidth(metricWidth(metricIds[c]));
        }
      case _TablePane.full:
        colWidths[0] = const FixedColumnWidth(116);
        for (var c = 0; c < metricIds.length; c++) {
          colWidths[c + 1] = FixedColumnWidth(metricWidth(metricIds[c]));
        }
    }

    final tableRows = <TableRow>[];
    switch (widget.part) {
      case _TablePart.all:
        tableRows.add(_headerRow(items));
        tableRows.add(_pointRow(items));
        for (var i = 0; i < widget.rows.length; i++) {
          final r = widget.rows[i];
          tableRows.add(_dataRow(r.$1, r.$2, rowIndex: i));
        }
        tableRows.add(
            _dataRow('TOTALS', widget.totals, isTotal: true, rowIndex: 0));
      case _TablePart.header:
        tableRows.add(_headerRow(items));
        tableRows.add(_pointRow(items));
      case _TablePart.body:
        for (var i = 0; i < widget.rows.length; i++) {
          final r = widget.rows[i];
          tableRows.add(_dataRow(r.$1, r.$2, rowIndex: i));
        }
        tableRows.add(
            _dataRow('TOTALS', widget.totals, isTotal: true, rowIndex: 0));
    }

    return Table(
      columnWidths: colWidths,
      border: TableBorder.all(color: _gridColor, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows,
    );
  }

  List<Widget> _paneChildren(List<Widget> cells) {
    switch (widget.pane) {
      case _TablePane.full:
        return cells;
      case _TablePane.frozen:
        return cells.isEmpty ? cells : [cells.first];
      case _TablePane.metrics:
        return cells.length <= 1 ? const [] : cells.sublist(1);
    }
  }

  TableRow _headerRow(List<LineItem> items) {
    return TableRow(
      decoration: const BoxDecoration(color: _headerBg),
      children: _paneChildren([
        _firstHeader(widget.firstColIsDate ? 'Date' : 'Name'),
        if (_vis(SheetColumnId.talked)) _vHeader('Total Talked'),
        for (final i in items)
          if (_vis(SheetColumnId.lineItem(i.id))) _vHeader(i.label),
        if (_vis(SheetColumnId.vip)) _vHeader('Total VIP'),
        if (_vis(SheetColumnId.aboveEco)) _vHeader('Above Eco'),
        if (_vis(SheetColumnId.ba)) _vHeader('BA %'),
        if (_vis(SheetColumnId.score)) _vHeader('Score'),
        if (_vis(SheetColumnId.revenue)) _vHeader('Revenue'),
      ]),
    );
  }

  Widget _firstHeader(String text) => Container(
        height: _headerH,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: _headerFg,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );

  Widget _vHeader(String text) => SizedBox(
        height: _headerH,
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 92,
              child: Text(text,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _headerFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
          ),
        ),
      );

  TableRow _pointRow(List<LineItem> items) {
    Widget cell(String v) => Container(
          height: 24,
          alignment: Alignment.center,
          child: Text(v,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
        );
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFEFF2F6)),
      children: _paneChildren([
        Container(
          height: 24,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 6),
          child: const Text('Point value',
              style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54)),
        ),
        if (_vis(SheetColumnId.talked)) cell('$kTalkedToPoints'),
        for (final i in items)
          if (_vis(SheetColumnId.lineItem(i.id))) cell('${pointOf(i)}'),
        if (_vis(SheetColumnId.vip)) cell(''),
        if (_vis(SheetColumnId.aboveEco)) cell(''),
        if (_vis(SheetColumnId.ba)) cell(''),
        if (_vis(SheetColumnId.score)) cell(''),
        if (_vis(SheetColumnId.revenue)) cell(''),
      ]),
    );
  }

  TableRow _dataRow(String label, Submission s,
      {bool isTotal = false, required int rowIndex}) {
    final items = kLineItems;
    final ba = s.businessAverage;
    final goal = s.baGoal > 0 ? s.baGoal : 40.0;
    final isTop =
        !isTotal && s.overallScore == widget.topScore && widget.topScore > 0;
    final isHovered = kIsWeb && _hoveredLabel == label;
    final w = isTotal ? FontWeight.w900 : FontWeight.w600;
    final zebraBg = rowIndex.isOdd ? _zebra : Colors.white;
    final rowColor = isTotal
        ? AppColors.blueSoft
        : (isTop
            ? const Color(0xFFEAF6EF)
            : (isHovered
                ? AppColors.blueSoft.withValues(alpha: 0.5)
                : zebraBg));

    Widget numCell(String v, {Color? color, FontWeight? weight}) => Container(
          height: _rowH,
          alignment: Alignment.center,
          child: Text(v,
              style: TextStyle(
                  fontSize: _bodyFont,
                  fontWeight: weight ?? w,
                  color: color ?? AppColors.navy)),
        );

    final first = Material(
      color: rowColor,
      child: InkWell(
        onTap: (isTotal || widget.onTapRow == null)
            ? null
            : () => widget.onTapRow!(s),
        onHover: kIsWeb && !isTotal && widget.onTapRow != null
            ? (hover) => setState(() => _hoveredLabel = hover ? label : null)
            : null,
        child: Container(
          height: _rowH,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: isTotal
              ? const BoxDecoration(
                  border: Border(top: BorderSide(color: _gridColor, width: 2)))
              : null,
          child: Row(
            children: [
              if (isTop)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.emoji_events_rounded,
                      size: 14, color: AppColors.success),
                ),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: _bodyFont,
                        color: AppColors.navy)),
              ),
            ],
          ),
        ),
      ),
    );

    final baCell = Container(
      height: _rowH,
      alignment: Alignment.center,
      color: baColor(ba, goal).withValues(alpha: 0.18),
      child: Text('${ba.toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: _bodyFont,
              fontWeight: FontWeight.w800,
              color: baColor(ba, goal))),
    );

    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
        border: isTotal
            ? const Border(top: BorderSide(color: _gridColor, width: 2))
            : null,
      ),
      children: _paneChildren([
        first,
        if (_vis(SheetColumnId.talked)) numCell('${s.talkedTo}'),
        for (final i in items)
          if (_vis(SheetColumnId.lineItem(i.id)))
            numCell('${s.countOf(i.id)}'),
        if (_vis(SheetColumnId.vip)) numCell('${s.totalMemberships}'),
        if (_vis(SheetColumnId.aboveEco)) numCell('${s.aboveEco}'),
        if (_vis(SheetColumnId.ba)) baCell,
        if (_vis(SheetColumnId.score))
          numCell('${s.overallScore}',
              weight: FontWeight.w900,
              color: isTop ? AppColors.success : AppColors.navy),
        if (_vis(SheetColumnId.revenue))
          numCell(_money.format(s.grandTotalRevenue), color: AppColors.success),
      ]),
    );
  }
}

/// Full-screen, pinch-to-zoom view of the sheet for small screens.
class _FullscreenSheet extends StatelessWidget {
  const _FullscreenSheet({required this.title, required this.table});
  final String title;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: InteractiveViewer(
        constrained: false,
        minScale: 0.4,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(80),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: table,
        ),
      ),
    );
  }
}

/// Thin rail shown when the pending panel is collapsed on wide screens.
class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({required this.count, required this.onExpand});
  final int count;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      child: Container(
        width: 52,
        color: AppColors.blueSoft,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.notifications_active_rounded,
                  color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
            const SizedBox(height: 8),
            const RotatedBox(
              quarterTurns: 1,
              child: Text('Pending approvals',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.navy)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide-screen right rail listing pending approvals.
class _PendingSidebar extends StatelessWidget {
  const _PendingSidebar({required this.onChanged, required this.onCollapse});
  final VoidCallback onChanged;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final pending = Store.instance.pendingSubmissions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.blueSoft,
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pending (${pending.length})',
                    style: TextStyles.subheading),
              ),
              IconButton(
                tooltip: 'Hide panel',
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: pending.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'All caught up',
                  message: 'New scorecards will show up here for approval.',
                )
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    for (final s in pending)
                      _PendingCard(submission: s, onChanged: onChanged),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Narrow-screen collapsible banner of pending approvals.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final pending = Store.instance.pendingSubmissions;
    if (pending.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.blueSoft,
      child: ExpansionTile(
        leading: const Icon(Icons.notifications_active_rounded,
            color: AppColors.navy),
        title: Text('Pending approvals (${pending.length})',
            style: TextStyles.subheading),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: [
          for (final s in pending)
            _PendingCard(submission: s, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.submission, required this.onChanged});
  final Submission submission;
  final VoidCallback onChanged;

  Future<void> _approve(BuildContext context) async {
    final err = await Store.instance.approveSubmission(submission.id);
    if (context.mounted) {
      showStoreMessage(context, err ?? 'Approved ${submission.employeeName}',
          error: err != null);
    }
    onChanged();
  }

  Future<void> _edit(BuildContext context) async {
    final result =
        await showSubmissionEditor(context, existing: submission);
    if (result == null) return;
    await Store.instance.updateSubmission(
      submission.id,
      counts: result.counts,
      baGoal: result.baGoal,
      talkedTo: result.talkedTo,
    );
    onChanged();
  }

  Future<void> _reject(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject scorecard?'),
        content: Text(
            'This permanently deletes ${submission.employeeName}\'s pending scorecard.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Store.instance.deleteSubmission(submission.id);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.employeeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Text(_shortDate.format(s.submittedAt),
                    style: TextStyles.caption),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Talked ${s.talkedTo} • BA ${s.businessAverage.toStringAsFixed(0)}% • '
              'Score ${s.overallScore} • ${_money.format(s.grandTotalRevenue)}',
              style: TextStyles.caption,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Reject',
                  onPressed: () => _reject(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
