import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/day_header.dart';
import '../../domain/sale.dart';
import 'sales_providers.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _query = '';
  DateTime? _day;
  bool _showCancelled = false;

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          IconButton(
            tooltip: _showCancelled ? 'Ẩn phiếu đã hủy' : 'Hiện phiếu đã hủy',
            icon: Icon(
              _showCancelled ? Icons.visibility : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _showCancelled = !_showCancelled),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.saleNew),
        icon: const Icon(Icons.add),
        label: const Text('Tạo phiếu bán'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo số tiền, người mua, mã phiếu',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _day == null
                  ? ActionChip(
                      avatar: const Icon(Icons.event, size: 18),
                      label: const Text('Lọc theo ngày'),
                      onPressed: _pickDay,
                    )
                  : InputChip(
                      avatar: const Icon(Icons.event, size: 18),
                      label: Text('Ngày ${formatDate(_day!)}'),
                      onPressed: _pickDay,
                      onDeleted: () => setState(() => _day = null),
                    ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có phiếu bán nào.\nBấm "Tạo phiếu bán" để bắt đầu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }
                final groups = groupSalesByDay(
                  filterSales(
                    all,
                    query: _query,
                    day: _day,
                    showCancelled: _showCancelled,
                  ),
                );
                if (groups.isEmpty) {
                  return const Center(child: Text('Không có phiếu phù hợp'));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    for (final g in groups) ...[
                      DayHeader(group: g),
                      for (final s in g.items) ...[
                        _SaleTile(sale: s),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = sale;
    final muted = s.isCancelled ? scheme.outline : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => context.push(Routes.saleDetail(s.id)),
        title: Row(
          children: [
            Flexible(
              child: Text(
                s.buyerName ?? 'Người mua lẻ',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            if (s.isCancelled) ...[
              const SizedBox(width: 8),
              Text('Đã hủy', style: TextStyle(fontSize: 12, color: scheme.error)),
            ],
          ],
        ),
        subtitle: Text(
          '${s.code} • ${DateFormat('HH:mm').format(s.saleDate)}'
          '${s.note != null ? '\n${s.note}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          formatVnd(s.totalAmount),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: muted ?? scheme.primary,
            decoration: s.isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
