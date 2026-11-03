import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/report.dart';
import 'report_charts.dart';
import 'reports_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.containing(
    ReportPeriodType.month,
    DateTime.now(),
  );

  bool get _isCurrent => _period.contains(DateTime.now());

  void _setType(ReportPeriodType type) => setState(
    () => _period = ReportPeriod.containing(type, DateTime.now()),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reportProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportPeriodType>(
            segments: [
              for (final t in ReportPeriodType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_period.type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setType(s.first),
          ),
          const SizedBox(height: 8),
          _PeriodNavigator(
            period: _period,
            canGoNext: !_isCurrent,
            onPrevious: () => setState(() => _period = _period.previous),
            onNext: () => setState(() => _period = _period.next),
            onToday: _isCurrent ? null : () => _setType(_period.type),
          ),
          const SizedBox(height: 8),
          ...async.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text(friendlyError(e))],
            data: (data) => _content(data),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(ReportData data) {
    final t = data.totals;
    return [
      _TotalsSection(totals: t),
      const SizedBox(height: 16),
      if (t.purchaseCount + t.saleCount == 0)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có phiếu thu mua hay bán nào trong kỳ này',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        )
      else ...[
        ChartCard(
          title: 'Thu mua và bán hàng',
          legend: const [
            LegendEntry(ReportColors.sale, 'Tiền bán'),
            LegendEntry(ReportColors.purchase, 'Tiền thu mua'),
          ],
          child: CashFlowChart(buckets: data.buckets, type: _period.type),
        ),
        const SizedBox(height: 12),
        ChartCard(
          title: 'Lợi nhuận',
          legend: const [
            LegendEntry(ReportColors.profit, 'Lãi'),
            LegendEntry(ReportColors.loss, 'Lỗ'),
          ],
          child: ProfitChart(buckets: data.buckets, type: _period.type),
        ),
        const SizedBox(height: 12),
        ReportTable(buckets: data.buckets, type: _period.type),
      ],
      const SizedBox(height: 12),
      const _MethodNote(),
    ];
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.period,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final ReportPeriod period;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// null khi đang ở kỳ hiện tại.
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Kỳ trước',
          iconSize: 28,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                period.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onToday != null)
                TextButton(
                  onPressed: onToday,
                  child: Text('Về ${period.type.label.toLowerCase()} này'),
                )
              else
                Text(
                  '${period.type.label} này',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Kỳ sau',
          iconSize: 28,
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.totals});

  final ReportTotals totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = totals;
    final profitColor = t.profit < 0 ? scheme.error : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lợi nhuận', style: TextStyle(fontSize: 16)),
                Text(
                  formatVnd(t.profit),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: profitColor,
                  ),
                ),
                Text(
                  '= Tổng tiền bán − Tổng tiền thu mua',
                  style: TextStyle(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Tổng tiền bán',
                  value: t.saleTotal,
                  count: '${t.saleCount} phiếu bán',
                  marker: ReportColors.sale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Tổng tiền thu mua',
                  value: t.purchaseTotal,
                  count: '${t.purchaseCount} phiếu thu mua',
                  marker: ReportColors.purchase,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.count,
    required this.marker,
  });

  final String label;
  final int value;
  final String count;
  final Color marker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Chấm màu trùng với màu cột trên biểu đồ.
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: marker,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(label)),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatVnd(value),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(count, style: TextStyle(color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _MethodNote extends StatelessWidget {
  const _MethodNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(color: scheme.onSecondaryContainer);
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Cách tính',
                  style: style.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lợi nhuận = Tổng tiền bán − Tổng tiền thu mua trong cùng kỳ. '
              'Chỉ tính phiếu chưa hủy.\n\n'
              'Đây là CHÊNH LỆCH DÒNG TIỀN, không phải lợi nhuận kế toán theo '
              'giá vốn: phiếu bán chỉ ghi tổng tiền nên không biết chính xác '
              'đã bán hàng nào, giá vốn bao nhiêu. Ví dụ tuần này mua nhiều '
              'để trữ mà chưa bán thì lợi nhuận tuần có thể âm.',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
