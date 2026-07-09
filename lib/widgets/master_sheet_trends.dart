import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../utils/master_sheet_stats.dart';
import '../utils/trends_visual_prefs.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _shortDay = DateFormat('M/d');

String _compactMoney(double v) {
  final abs = v.abs();
  if (abs >= 1000) {
    final k = v / 1000;
    final s = k == k.roundToDouble()
        ? k.toStringAsFixed(0)
        : k.toStringAsFixed(1);
    return '\$${s}k';
  }
  return _money.format(v);
}

/// Soft slate chart palette (avoids heavy navy bars).
const _chartLine = Color(0xFF6B7280);
const _chartFill = Color(0xFF9CA3AF);
const _chartBar = Color(0xFF9CA3AF);
const _chartBarAlt = Color(0xFFD1D5DB);
const _chartGrid = Color(0xFFE5E7EB);

Widget _clipChart(Widget child) => ClipRect(
      child: child,
    );

/// Summary chips + revenue-over-time + employee comparison charts.
class MasterSheetTrends extends StatelessWidget {
  const MasterSheetTrends({
    super.key,
    required this.stats,
    required this.prefs,
  });

  final MasterSheetStats stats;
  final TrendsVisualPrefs prefs;

  @override
  Widget build(BuildContext context) {
    if (prefs.panelMode == TrendsPanelMode.hidden) {
      return const SizedBox.shrink();
    }

    final showCharts = prefs.panelMode == TrendsPanelMode.expanded;
    final children = <Widget>[];

    if (prefs.showSummary) {
      children.add(_SummaryRow(stats: stats));
    }

    if (showCharts) {
      if (prefs.showRevenueOverTime) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'Revenue over time',
          child: SizedBox(
            height: 180,
            child: stats.revenueByDay.isEmpty
                ? const _EmptyChart(
                    message: 'No approved shifts in this period')
                : _clipChart(_RevenueLineChart(points: stats.revenueByDay)),
          ),
        ));
      }
      if (prefs.showByEmployee) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'By employee',
          child: SizedBox(
            height: 200,
            child: stats.employeeTotals.isEmpty
                ? const _EmptyChart(message: 'No employee totals yet')
                : _clipChart(_EmployeeBarChart(rows: stats.employeeTotals)),
          ),
        ));
      }
      if (prefs.showBaByEmployee) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'BA % by employee',
          child: SizedBox(
            height: 200,
            child: stats.employeeBa.isEmpty
                ? const _EmptyChart(message: 'No BA data yet')
                : _clipChart(_EmployeeBaChart(rows: stats.employeeBa)),
          ),
        ));
      }
      if (prefs.showMembershipMix) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(_ChartCard(
          title: 'Memberships vs singles',
          child: SizedBox(
            height: 220,
            child: stats.membershipMix.isEmpty
                ? const _EmptyChart(message: 'No wash mix yet')
                : _clipChart(_MembershipMixChart(rows: stats.membershipMix)),
          ),
        ));
      }
    }

    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No visuals enabled — open Visuals to show charts.',
          style: TextStyles.caption,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});
  final MasterSheetStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Period total',
            value: _money.format(stats.totalRevenue),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Shifts',
            value: '${stats.shiftCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Avg / shift',
            value: _money.format(stats.avgRevenuePerShift),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: TextStyles.subheading),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyles.subheading),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: TextStyles.caption),
    );
  }
}

Widget _shortName(String label) {
  final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(short, style: TextStyles.caption.copyWith(fontSize: 10)),
  );
}

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({required this.points});
  final List<DayRevenue> points;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenue),
    ];
    final maxY =
        points.map((p) => p.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;
    final chart = LineChart(
      LineChartData(
        minY: 0,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: _chartGrid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: chartMaxY / 3,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _compactMoney(v),
                    style: TextStyles.caption.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortDay.format(points[i].day),
                    style: TextStyles.caption.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: points.length > 1,
            color: _chartLine,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: _chartLine,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _chartFill.withValues(alpha: 0.35),
                  _chartFill.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (points.length != 1) return chart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: chart),
        const SizedBox(height: 4),
        Text(
          '${_shortDay.format(points.first.day)} · ${_money.format(points.first.revenue)}',
          style: TextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmployeeBarChart extends StatelessWidget {
  const _EmployeeBarChart({required this.rows});
  final List<EmployeeRevenue> rows;

  @override
  Widget build(BuildContext context) {
    final maxY =
        rows.map((e) => e.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;
    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: _chartGrid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: chartMaxY / 3,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _compactMoney(v),
                    style: TextStyles.caption.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                return _shortName(rows[i].name);
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].revenue,
                  color: _chartBar,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmployeeBaChart extends StatelessWidget {
  const _EmployeeBaChart({required this.rows});
  final List<EmployeeBa> rows;

  @override
  Widget build(BuildContext context) {
    final maxY = rows.map((e) => e.ba).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = (maxY <= 0 ? 40.0 : maxY * 1.15).clamp(40.0, 120.0);
    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: _chartGrid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: chartMaxY / 3,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${v.round()}%',
                    style: TextStyles.caption.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                return _shortName(rows[i].name);
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].ba,
                  color: _chartBar,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MembershipMixChart extends StatelessWidget {
  const _MembershipMixChart({required this.rows});
  final List<EmployeeWashMix> rows;

  @override
  Widget build(BuildContext context) {
    final maxY = rows
        .map((e) => e.memberships > e.singles ? e.memberships : e.singles)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Memberships · Singles',
          style: TextStyles.caption.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => const FlLine(
                  color: _chartGrid,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: chartMaxY / 3,
                    getTitlesWidget: (v, meta) {
                      if (v == meta.max) return const SizedBox.shrink();
                      return Text(
                        '${v.round()}',
                        style: TextStyles.caption.copyWith(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      return _shortName(rows[i].name);
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < rows.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: rows[i].memberships.toDouble(),
                        color: _chartBar,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: rows[i].singles.toDouble(),
                        color: _chartBarAlt,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
