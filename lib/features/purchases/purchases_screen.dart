import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../domain/purchase.dart';
import 'purchases_providers.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  bool _showCancelled = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu mua'),
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
        onPressed: () => context.push(Routes.purchaseNew),
        icon: const Icon(Icons.add),
        label: const Text('Tạo phiếu thu mua'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (purchases) {
          final groups = groupPurchasesByDay(
            purchases,
            showCancelled: _showCancelled,
          );
          if (groups.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có phiếu thu mua nào.\nBấm "Tạo phiếu thu mua" để bắt đầu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final g in groups) ...[
                _DayHeader(group: g),
                for (final p in g.purchases) ...[
                  _PurchaseTile(purchase: p),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final PurchaseDayGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = DateFormat('EEEE', 'vi').format(group.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Text(
            '${weekday[0].toUpperCase()}${weekday.substring(1)}, '
            '${formatDate(group.day)}',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          Text(
            formatVnd(group.activeTotal),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = purchase;
    final muted = p.isCancelled ? scheme.outline : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => context.push(Routes.purchaseDetail(p.id)),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.sellerName ?? 'Khách lẻ',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            if (p.isCancelled) ...[
              const SizedBox(width: 8),
              Text('Đã hủy', style: TextStyle(fontSize: 12, color: scheme.error)),
            ],
          ],
        ),
        subtitle: Text(
          '${p.code} • ${DateFormat('HH:mm').format(p.purchaseDate)} • '
          '${p.itemCount} mặt hàng',
        ),
        trailing: Text(
          formatVnd(p.totalAmount),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: muted,
            decoration: p.isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
