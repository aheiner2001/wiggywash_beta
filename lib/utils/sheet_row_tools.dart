import '../models/submission.dart';
import 'sheet_column.dart';
import 'sheet_tools_prefs.dart';
import 'xlsx.dart' show MasterSheetRow;

/// Filters then sorts display rows. Does not include a totals row.
List<MasterSheetRow> applySheetRowTools({
  required List<MasterSheetRow> rows,
  required SheetToolsPrefs prefs,
  required Set<String>? selectedEmployees,
  required bool firstColIsDate,
}) {
  var list = List<MasterSheetRow>.from(rows);

  if (!firstColIsDate &&
      selectedEmployees != null &&
      selectedEmployees.isNotEmpty) {
    list = list
        .where((r) => selectedEmployees.contains(r.submission.employeeName))
        .toList();
  }

  if (prefs.minBa != null) {
    final min = prefs.minBa!;
    list = list.where((r) => r.submission.businessAverage >= min).toList();
  }
  if (prefs.minRevenue != null) {
    final min = prefs.minRevenue!;
    list = list.where((r) => r.submission.grandTotalRevenue >= min).toList();
  }

  int cmp(MasterSheetRow a, MasterSheetRow b) {
    final sa = a.submission;
    final sb = b.submission;
    int primary;
    switch (prefs.sortKey) {
      case SheetSortKey.nameOrDate:
        primary = firstColIsDate
            ? sa.submittedAt.compareTo(sb.submittedAt)
            : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      case SheetSortKey.revenue:
        primary = sa.grandTotalRevenue.compareTo(sb.grandTotalRevenue);
      case SheetSortKey.ba:
        primary = sa.businessAverage.compareTo(sb.businessAverage);
      case SheetSortKey.score:
        primary = sa.overallScore.compareTo(sb.overallScore);
      case SheetSortKey.talked:
        primary = sa.talkedTo.compareTo(sb.talkedTo);
    }
    if (!prefs.sortAsc) primary = -primary;
    if (primary != 0) return primary;
    return a.label.compareTo(b.label);
  }

  list.sort(cmp);
  return list;
}

/// Re-aggregate totals from visible rows using the same aggregator as the screen.
Submission totalsFromVisibleRows({
  required List<MasterSheetRow> visible,
  required DateTime anchor,
  required Submission Function(String, List<Submission>, DateTime) aggregate,
}) {
  final subs = visible.map((r) => r.submission).toList();
  return aggregate('TOTALS', subs, anchor);
}

int activeFilterCount({
  required SheetToolsPrefs prefs,
  required Set<String>? selectedEmployees,
  required bool firstColIsDate,
}) {
  var n = 0;
  if (!firstColIsDate &&
      selectedEmployees != null &&
      selectedEmployees.isNotEmpty) {
    n++;
  }
  if (prefs.minBa != null) n++;
  if (prefs.minRevenue != null) n++;
  return n;
}
