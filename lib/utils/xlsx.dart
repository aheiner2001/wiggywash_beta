import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../theme.dart';

/// One row in the Master Sheet grid (name/date label + aggregated submission).
class MasterSheetRow {
  const MasterSheetRow({required this.label, required this.submission});
  final String label;
  final Submission submission;
}

/// Builds an `.xlsx` file matching the on-screen Master Sheet layout.
Uint8List buildMasterSheetXlsx({
  required List<MasterSheetRow> rows,
  required Submission totals,
  required String title,
  required String viewLabel,
  bool firstColIsDate = false,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Master Sheet'];
  excel.delete('Sheet1');

  final items = kLineItems;
  final headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('1B2A4A'),
    fontColorHex: ExcelColor.fromHexString('FFFFFF'),
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
  );
  final pointStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('EFF2F6'),
    fontColorHex: ExcelColor.fromHexString('1B2A4A'),
    bold: true,
  );
  final totalStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('E3F0FA'),
    fontColorHex: ExcelColor.fromHexString('1B2A4A'),
    bold: true,
  );

  var row = 0;
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      .value = TextCellValue('$title · $viewLabel');
  row += 2;

  void setCell(int c, int r, CellValue? value, {CellStyle? style}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = value;
    if (style != null) cell.cellStyle = style;
  }

  final headers = <String>[
    firstColIsDate ? 'Date' : 'Name',
    'Total Talked',
    ...items.map((i) => i.label),
    'Total VIP',
    'Above Eco',
    'BA %',
    'Score',
    'Revenue',
  ];
  for (var c = 0; c < headers.length; c++) {
    setCell(c, row, TextCellValue(headers[c]), style: headerStyle);
  }
  row++;

  setCell(0, row, TextCellValue('Point value'), style: pointStyle);
  setCell(1, row, IntCellValue(kTalkedToPoints), style: pointStyle);
  for (var i = 0; i < items.length; i++) {
    setCell(2 + i, row, IntCellValue(pointOf(items[i])), style: pointStyle);
  }
  row++;

  for (final entry in rows) {
  final s = entry.submission;
    var col = 0;
    setCell(col++, row, TextCellValue(entry.label));
    setCell(col++, row, IntCellValue(s.talkedTo));
    for (final i in items) {
      setCell(col++, row, IntCellValue(s.countOf(i.id)));
    }
    setCell(col++, row, IntCellValue(s.totalMemberships));
    setCell(col++, row, IntCellValue(s.aboveEco));
    final ba = s.businessAverage;
    final goal = s.baGoal > 0 ? s.baGoal : 40.0;
    setCell(
      col++,
      row,
      TextCellValue('${ba.toStringAsFixed(0)}%'),
      style: CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(_baBackgroundHex(ba, goal)),
        fontColorHex: ExcelColor.fromHexString(_baFontHex(ba, goal)),
        bold: true,
      ),
    );
    setCell(col++, row, IntCellValue(s.overallScore));
    setCell(col++, row, TextCellValue(s.grandTotalRevenue.toStringAsFixed(0)));
    row++;
  }

  var col = 0;
  setCell(col++, row, TextCellValue('TOTALS'), style: totalStyle);
  setCell(col++, row, IntCellValue(totals.talkedTo), style: totalStyle);
  for (final i in items) {
    setCell(col++, row, IntCellValue(totals.countOf(i.id)), style: totalStyle);
  }
  setCell(col++, row, IntCellValue(totals.totalMemberships), style: totalStyle);
  setCell(col++, row, IntCellValue(totals.aboveEco), style: totalStyle);
  final tBa = totals.businessAverage;
  final tGoal = totals.baGoal > 0 ? totals.baGoal : 40.0;
  setCell(
    col++,
    row,
    TextCellValue('${tBa.toStringAsFixed(0)}%'),
    style: CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_baBackgroundHex(tBa, tGoal)),
      fontColorHex: ExcelColor.fromHexString(_baFontHex(tBa, tGoal)),
      bold: true,
    ),
  );
  setCell(col++, row, IntCellValue(totals.overallScore), style: totalStyle);
  setCell(
    col++,
    row,
    TextCellValue(totals.grandTotalRevenue.toStringAsFixed(0)),
    style: totalStyle,
  );

  final bytes = excel.encode();
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Excel encode returned empty bytes');
  }
  return Uint8List.fromList(bytes);
}

String _baBackgroundHex(double actual, double goal) {
  final c = baColor(actual, goal);
  if (c == AppColors.success) return 'EAF6EF';
  if (c == AppColors.warning) return 'FFF4E0';
  if (c == AppColors.danger) return 'FFE8EC';
  return 'FFFFFF';
}

String _baFontHex(double actual, double goal) {
  final c = baColor(actual, goal);
  if (c == AppColors.success) return '2E7D52';
  if (c == AppColors.warning) return 'E8A33D';
  if (c == AppColors.danger) return 'B00020';
  return '1B2A4A';
}

/// Tab-separated grid for clipboard paste into Excel/Sheets.
String masterSheetToTsv({
  required List<MasterSheetRow> rows,
  required Submission totals,
  required String title,
  required String viewLabel,
  bool firstColIsDate = false,
}) {
  final items = kLineItems;
  final lines = <String>['$title · $viewLabel', ''];
  final headers = <String>[
    firstColIsDate ? 'Date' : 'Name',
    'Total Talked',
    ...items.map((i) => i.label),
    'Total VIP',
    'Above Eco',
    'BA %',
    'Score',
    'Revenue',
  ];
  lines.add(headers.join('\t'));
  lines.add([
    'Point value',
    '$kTalkedToPoints',
    ...items.map((i) => '${pointOf(i)}'),
    '',
    '',
    '',
    '',
    '',
  ].join('\t'));
  for (final entry in rows) {
    final s = entry.submission;
    lines.add([
      entry.label,
      '${s.talkedTo}',
      ...items.map((i) => '${s.countOf(i.id)}'),
      '${s.totalMemberships}',
      '${s.aboveEco}',
      '${s.businessAverage.toStringAsFixed(0)}%',
      '${s.overallScore}',
      s.grandTotalRevenue.toStringAsFixed(0),
    ].join('\t'));
  }
  final t = totals;
  lines.add([
    'TOTALS',
    '${t.talkedTo}',
    ...items.map((i) => '${t.countOf(i.id)}'),
    '${t.totalMemberships}',
    '${t.aboveEco}',
    '${t.businessAverage.toStringAsFixed(0)}%',
    '${t.overallScore}',
    t.grandTotalRevenue.toStringAsFixed(0),
  ].join('\t'));
  return lines.join('\n');
}
