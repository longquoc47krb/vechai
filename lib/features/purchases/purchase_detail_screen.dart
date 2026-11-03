import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../domain/purchase.dart';
import 'purchases_providers.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final String purchaseId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Purchase p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hủy phiếu ${p.code}?',
      message:
          'Phiếu ${formatVnd(p.totalAmount)} sẽ không còn được tính vào kho '
          'hàng và báo cáo. Dữ liệu phiếu vẫn được giữ lại để tra cứu.',
      confirmLabel: 'Hủy phiếu',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(purchaseRepositoryProvider).cancel(p.id);
      refreshPurchaseData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy phiếu ${p.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDetailProvider(purchaseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết phiếu thu mua')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (p) {
          if (p == null) return const Center(child: Text('Không tìm thấy phiếu'));
          return _Body(
            purchase: p,
            onEdit: () => context.push(Routes.purchaseEdit(p.id)),
            onCancel: () => _cancel(context, ref, p),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.purchase,
    required this.onEdit,
    required this.onCancel,
  });

  final Purchase purchase;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = purchase;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (p.isCancelled) ...[
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.block, color: scheme.onErrorContainer),
              title: Text(
                'Phiếu đã hủy',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
              subtitle: Text(
                'Không tính vào kho hàng và báo cáo',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.code, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _InfoRow(Icons.event, formatDateTime(p.purchaseDate)),
                _InfoRow(Icons.person_outline, p.sellerName ?? 'Khách lẻ'),
                if (p.note != null) _InfoRow(Icons.notes, p.note!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Mặt hàng (${p.items.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (index, item) in p.items.indexed) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  title: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${formatQuantity(item.quantity)} ${item.unit} × '
                    '${formatVnd(item.unitPrice)}',
                  ),
                  trailing: Text(
                    formatVnd(item.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                title: const Text(
                  'Tổng tiền thu mua',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  formatVnd(p.totalAmount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: p.isCancelled ? scheme.outline : scheme.primary,
                    decoration: p.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!p.isCancelled) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                  onPressed: onCancel,
                  icon: const Icon(Icons.block),
                  label: const Text('Hủy phiếu'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Sửa phiếu'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Tạo lúc ${formatDateTime(p.createdAt.toLocal())}'
          '${p.updatedAt != p.createdAt ? ' • Cập nhật ${formatDateTime(p.updatedAt.toLocal())}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
