import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../domain/report.dart';

/// Màu biểu đồ: lấy từ bảng màu đã kiểm tra khả năng phân biệt cho người
/// mù màu (xanh dương / cam; lãi xanh dương / lỗ đỏ) trên nền trắng.
class ReportColors {
  ReportColors._();

  static const sale = Color(0xFFEB6834);
  static const purchase = Color(0xFF2A78D6);
  static const profit = Color(0xFF2A78D6);
  static const loss = Color(0xFFE34948);
}

class LegendEntry {
  const LegendEntry(this.color, this.label);

  final Color color;
  final String label;
}

/// Khung chứa 1 biểu đồ: tiêu đề + chú thích + biểu đồ.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.legend,
    required this.child,
  });

  final String title;
  final List<LegendEntry> legend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 16,
                children: [
                  for (final e in legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: e.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(e.label, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
            const SizedBox(height: 4),
            Text(
              'Chạm vào cột để xem số tiền',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu đồ cột nhóm: tiền bán và tiền thu mua theo từng ngày / tháng.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({super.key, required this.buckets, required this.type});

  final List<ReportBucket> buckets;
  final ReportPeriodType type;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold<int>(
      0,
      (m, b) => math.max(m, math.max(b.totals.saleTotal, b.totals.purchaseTotal)),
    );
    final axis = _NiceAxis.of(0, maxValue.toDouble());
    final rodWidth = _rodWidth(type, grouped: true);

    return BarChart(
      BarChartData(
        minY: axis.min,
        maxY: axis.max,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (final (i, b) in buckets.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2, // khe 2px giữa 2 cột cạnh nhau
              barRods: [
                _rod(b.totals.saleTotal, ReportColors.sale, rodWidth),
                _rod(b.totals.purchaseTotal, ReportColors.purchase, rodWidth),
              ],
            ),
        ],
        titlesData: _titles(context, axis, buckets, type),
        gridData: _grid(context, axis),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: _tooltip(
            context,
            (groupIndex, rodIndex) {
              final b = buckets[groupIndex];
              return rodIndex == 0
                  ? '${_longLabel(b.range, type)}\n'
                        'Bán: ${formatVnd(b.totals.saleTotal)}'
                  : 'Thu mua: ${formatVnd(b.totals.purchaseTotal)}';
            },
          ),
        ),
      ),
    );
  }
}

/// Biểu đồ lợi nhuận (bán − thu mua) từng ngày / tháng: lãi lên trên, lỗ
/// xuống dưới đường 0.
class ProfitChart extends StatelessWidget {
  const ProfitChart({super.key, required this.buckets, required this.type});

  final List<ReportBucket> buckets;
  final ReportPeriodType type;

  @override
  Widget build(BuildContext context) {
    final profits = buckets.map((b) => b.totals.profit).toList();
    final axis = _NiceAxis.of(
      math.min(0, profits.fold(0, math.min)).toDouble(),
      math.max(0, profits.fold(0, math.max)).toDouble(),
    );
    final rodWidth = _rodWidth(type, grouped: false);

    return BarChart(
      BarChartData(
        minY: axis.min,
        maxY: axis.max,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (final (i, p) in profits.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                _rod(
                  p,
                  p < 0 ? ReportColors.loss : ReportColors.profit,
                  rodWidth,
                ),
              ],
            ),
        ],
        titlesData: _titles(context, axis, buckets, type),
        gridData: _grid(context, axis),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: Theme.of(context).colorScheme.outline,
              strokeWidth: 1,
            ),
          ],
        ),
        barTouchData: BarTouchData(
          touchTooltipData: _tooltip(context, (groupIndex, _) {
            final b = buckets[groupIndex];
            final p = b.totals.profit;
            return '${_longLabel(b.range, type)}\n'
                '${p < 0 ? 'Lỗ' : 'Lãi'}: ${formatVnd(p)}';
          }),
        ),
      ),
    );
  }
}

/// Bảng số liệu (cho ai cần số chính xác / khó phân biệt màu).
/// Chỉ liệt kê ngày / tháng có phát sinh.
class ReportTable extends StatelessWidget {
  const ReportTable({super.key, required this.buckets, required this.type});

  final List<ReportBucket> buckets;
  final ReportPeriodType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = buckets
        .where((b) => b.totals.saleCount + b.totals.purchaseCount > 0)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.table_rows_outlined),
        title: const Text('Bảng số liệu chi tiết'),
        subtitle: Text('${rows.length} ${type == ReportPeriodType.year ? 'tháng' : 'ngày'} có phát sinh'),
        children: [
          for (final b in rows) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(
                _longLabel(b.range, type),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Bán ${formatVnd(b.totals.saleTotal)}\n'
                'Thu mua ${formatVnd(b.totals.purchaseTotal)}',
              ),
              isThreeLine: true,
              trailing: Text(
                formatVnd(b.totals.profit),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: b.totals.profit < 0 ? scheme.error : scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phần dùng chung cho 2 biểu đồ

/// Trục Y "đẹp": 4 khoảng chia tròn (0, 500k, 1tr, 1,5tr...).
class _NiceAxis {
  const _NiceAxis(this.min, this.max, this.interval);

  final double min;
  final double max;
  final double interval;

  factory _NiceAxis.of(double low, double high) {
    if (low == 0 && high == 0) return const _NiceAxis(0, 1000, 250);
    final raw = (high - low) / 4;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final step = [1, 2, 2.5, 5, 10]
        .map((m) => m * magnitude)
        .firstWhere((s) => s >= raw);
    return _NiceAxis(
      (low / step).floor() * step,
      (high / step).ceil() * step,
      step,
    );
  }
}

/// Cột mảnh, bo 4px ở ĐẦU cột, vuông ở đường gốc.
BarChartRodData _rod(int value, Color color, double width) {
  const r = Radius.circular(4);
  return BarChartRodData(
    toY: value.toDouble(),
    color: color,
    width: width,
    borderRadius: value >= 0
        ? const BorderRadius.vertical(top: r)
        : const BorderRadius.vertical(bottom: r),
  );
}

double _rodWidth(ReportPeriodType type, {required bool grouped}) =>
    switch (type) {
      ReportPeriodType.week => grouped ? 14 : 20,
      ReportPeriodType.month => grouped ? 3 : 5,
      ReportPeriodType.year => grouped ? 8 : 14,
    };

FlTitlesData _titles(
  BuildContext context,
  _NiceAxis axis,
  List<ReportBucket> buckets,
  ReportPeriodType type,
) {
  final style = Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Theme.of(context).colorScheme.outline,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        interval: axis.interval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(formatCompactVnd(value), style: style),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          // Tháng có ~30 cột: chỉ ghi nhãn ngày 1, 5, 10, 15...
          final show =
              type != ReportPeriodType.month || i == 0 || (i + 1) % 5 == 0;
          if (!show || i < 0 || i >= buckets.length) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            child: Text(buckets[i].range.label, style: style),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context, _NiceAxis axis) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: axis.interval,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
    strokeWidth: 1,
  ),
);

BarTouchTooltipData _tooltip(
  BuildContext context,
  String Function(int groupIndex, int rodIndex) text,
) {
  final scheme = Theme.of(context).colorScheme;
  return BarTouchTooltipData(
    getTooltipColor: (_) => scheme.inverseSurface,
    tooltipBorderRadius: BorderRadius.circular(8),
    maxContentWidth: 200,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
      text(groupIndex, rodIndex),
      TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
    ),
  );
}

/// Nhãn đầy đủ: "Thứ Hai 03/11", "Ngày 15/11", "Tháng 11/2026".
String _longLabel(ReportBucketRange range, ReportPeriodType type) {
  final d = range.start;
  return switch (type) {
    ReportPeriodType.week =>
      '${toBeginningOfSentenceCase(DateFormat('EEEE', 'vi').format(d))} '
          '${DateFormat('dd/MM').format(d)}',
    ReportPeriodType.month => 'Ngày ${DateFormat('dd/MM').format(d)}',
    ReportPeriodType.year => 'Tháng ${DateFormat('MM/yyyy').format(d)}',
  };
}
