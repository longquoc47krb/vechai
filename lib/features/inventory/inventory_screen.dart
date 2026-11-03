import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../domain/inventory.dart';
import 'inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  InventoryPeriod _period = InventoryPeriod.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryProvider(_period));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kho hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.secondaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: scheme.onSecondaryContainer,
              ),
              title: Text(
                'Đây là số lượng ĐÃ THU MUA',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              subtitle: Text(
                'Không phải tồn kho thực tế, vì phiếu bán chỉ ghi tổng tiền, '
                'không trừ từng mặt hàng.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<InventoryPeriod>(
            segments: [
              for (final p in InventoryPeriod.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          ...async.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text(friendlyError(e))],
            data: (rows) => rows.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Chưa có hàng thu mua trong khoảng thời gian này',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ]
                : [
                    _TotalCard(rows: rows),
                    const SizedBox(height: 12),
                    for (final row in rows) ...[
                      _InventoryTile(row: row),
                      const SizedBox(height: 8),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.rows});

  final List<InventoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = rows.fold(0, (sum, r) => sum + r.totalAmount);
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng giá trị thu mua • ${rows.length} mặt hàng',
              style: TextStyle(color: scheme.onPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              formatVnd(total),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.row});

  final InventoryRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = row;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          Routes.productHistory(r.productId),
          extra: r.productName,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.productName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatQuantity(r.totalQuantity)} ${r.unit}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text('Giá trị: ${formatVnd(r.totalAmount)}'),
                        Text('TB: ${formatVnd(r.averagePrice)}/${r.unit}'),
                        Text('${r.purchaseCount} phiếu'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
