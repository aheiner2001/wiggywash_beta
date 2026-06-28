import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/csv.dart';
import '../utils/exporter.dart';
import '../widgets/profile_menu.dart';
import '../widgets/store_message.dart';
import '../widgets/submission_editor.dart';
import '../widgets/ui_kit.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _dayLabel = DateFormat('EEE, MMM d');
final _monthLabel = DateFormat('MMMM yyyy');
final _shortDate = DateFormat('M/d');

enum _View { team, member, month }

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

  Future<void> _export() async {
    final subs = _scope;
    if (subs.isEmpty) {
      showStoreMessage(context, 'Nothing to export here yet.', error: true);
      return;
    }
    final loc = Store.instance.activeLocation?.name ?? 'wiggywash';
    final slug = loc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    try {
      await exportCsv('$slug-${_view.name}.csv', submissionsToCsv(subs));
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
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _export,
            icon: const Icon(Icons.download_rounded),
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
                onView: (v) => setState(() => _view = v),
                onShift: _shift,
                onMember: (m) => setState(() => _member = m),
                onDrill: _drillToMember,
                onEdit: _editApproved,
                aggregate: _aggregate,
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
    required this.onView,
    required this.onShift,
    required this.onMember,
    required this.onDrill,
    required this.onEdit,
    required this.aggregate,
  });

  final _View view;
  final DateTime anchor;
  final String? member;
  final List<Submission> scope;
  final ValueChanged<_View> onView;
  final ValueChanged<int> onShift;
  final ValueChanged<String?> onMember;
  final ValueChanged<String> onDrill;
  final ValueChanged<Submission> onEdit;
  final Submission Function(String, List<Submission>, DateTime) aggregate;

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
        Expanded(child: _buildGrid(context)),
      ],
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

    // Build the list of (label, aggregated submission) rows.
    final rows = <(String, Submission)>[];
    if (isDaily) {
      final byDay = [...scope]
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
      for (final s in byDay) {
        rows.add((_shortDate.format(s.submittedAt), s));
      }
    } else {
      final byName = <String, List<Submission>>{};
      for (final s in scope) {
        byName.putIfAbsent(s.employeeName, () => []).add(s);
      }
      final names = byName.keys.toList()..sort();
      for (final n in names) {
        rows.add((n, aggregate(n, byName[n]!, anchor)));
      }
    }
    final totals = aggregate('TOTALS', scope, anchor);
    final topScore = rows.isEmpty
        ? 0
        : rows.map((r) => r.$2.overallScore).reduce((a, b) => a > b ? a : b);

    final title = isDaily
        ? '${member ?? ''} · ${_monthLabel.format(anchor)}'
        : (view == _View.team
            ? _dayLabel.format(anchor)
            : _monthLabel.format(anchor));

    _SpreadsheetTable table({void Function(Submission)? onTap}) =>
        _SpreadsheetTable(
          rows: rows,
          totals: totals,
          topScore: topScore,
          firstColIsDate: isDaily,
          onTapRow: onTap,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                child: table(
                  onTap: (s) =>
                      isDaily ? onEdit(s) : onDrill(s.employeeName),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Clean spreadsheet grid (à la the BA MASTER DOC): fixed columns, gridlines,
/// rotated headers, a point-value row, color-coded BA, and a totals row.
class _SpreadsheetTable extends StatelessWidget {
  const _SpreadsheetTable({
    required this.rows,
    required this.totals,
    required this.topScore,
    required this.firstColIsDate,
    this.onTapRow,
  });

  final List<(String, Submission)> rows;
  final Submission totals;
  final int topScore;
  final bool firstColIsDate;
  final void Function(Submission)? onTapRow;

  static const _gridColor = Color(0xFFD7DCE3);

  @override
  Widget build(BuildContext context) {
    final items = kLineItems;
    // talked + items + VIP + AbvEco are the plain 50px numeric columns.
    final numericCols = 1 + items.length + 2;
    final colWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(116),
      for (var c = 1; c <= numericCols; c++) c: const FixedColumnWidth(50),
      numericCols + 1: const FixedColumnWidth(58), // BA %
      numericCols + 2: const FixedColumnWidth(54), // Score
      numericCols + 3: const FixedColumnWidth(82), // Revenue
    };

    return Table(
      columnWidths: colWidths,
      border: TableBorder.all(color: _gridColor, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(items),
        _pointRow(items),
        for (final r in rows) _dataRow(r.$1, r.$2),
        _dataRow('TOTALS', totals, isTotal: true),
      ],
    );
  }

  TableRow _headerRow(List<LineItem> items) {
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.navy),
      children: [
        _firstHeader(firstColIsDate ? 'Date' : 'Name'),
        _vHeader('Total Talked'),
        for (final i in items) _vHeader(i.label),
        _vHeader('Total VIP'),
        _vHeader('Above Eco'),
        _vHeader('BA %'),
        _vHeader('Score'),
        _vHeader('Revenue'),
      ],
    );
  }

  Widget _firstHeader(String text) => Container(
        height: 104,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );

  Widget _vHeader(String text) => SizedBox(
        height: 104,
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
                      color: Colors.white,
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
      children: [
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
        cell('$kTalkedToPoints'),
        for (final i in items) cell('${pointOf(i)}'),
        cell(''),
        cell(''),
        cell(''),
        cell(''),
        cell(''),
      ],
    );
  }

  TableRow _dataRow(String label, Submission s, {bool isTotal = false}) {
    final items = kLineItems;
    final ba = s.businessAverage;
    final goal = s.baGoal > 0 ? s.baGoal : 40.0;
    final isTop = !isTotal && s.overallScore == topScore && topScore > 0;
    final w = isTotal ? FontWeight.w900 : FontWeight.w600;
    final rowColor = isTotal
        ? AppColors.blueSoft
        : (isTop ? const Color(0xFFEAF6EF) : Colors.white);

    Widget numCell(String v, {Color? color, FontWeight? weight}) => Container(
          height: 34,
          alignment: Alignment.center,
          child: Text(v,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: weight ?? w,
                  color: color ?? AppColors.navy)),
        );

    final first = Material(
      color: rowColor,
      child: InkWell(
        onTap: (isTotal || onTapRow == null) ? null : () => onTapRow!(s),
        child: Container(
          height: 34,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.navy)),
              ),
            ],
          ),
        ),
      ),
    );

    final baCell = Container(
      height: 34,
      alignment: Alignment.center,
      color: baColor(ba, goal).withValues(alpha: 0.18),
      child: Text('${ba.toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: baColor(ba, goal))),
    );

    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: [
        first,
        numCell('${s.talkedTo}'),
        for (final i in items) numCell('${s.countOf(i.id)}'),
        numCell('${s.totalMemberships}'),
        numCell('${s.aboveEco}'),
        baCell,
        numCell('${s.overallScore}',
            weight: FontWeight.w900,
            color: isTop ? AppColors.success : AppColors.navy),
        numCell(_money.format(s.grandTotalRevenue), color: AppColors.success),
      ],
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
