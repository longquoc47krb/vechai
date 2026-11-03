import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/repositories/sale_repository.dart';
import '../../domain/sale.dart';
import 'sales_providers.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Sale s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hủy phiếu ${s.code}?',
      message:
          'Phiếu bán ${formatVnd(s.totalAmount)} sẽ không còn được tính vào '
          'báo cáo. Dữ liệu phiếu vẫn được giữ lại để tra cứu.',
      confirmLabel: 'Hủy phiếu',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(saleRepositoryProvider).cancel(s.id);
      refreshSaleData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy phiếu ${s.code}')),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết phiếu bán')),
      body: ref
          .watch(saleDetailProvider(saleId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyError(e))),
            data: (s) {
              if (s == null) {
                return const Center(child: Text('Không tìm thấy phiếu'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (s.isCancelled) ...[
                    Card(
                      color: scheme.errorContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.block,
                          color: scheme.onErrorContainer,
                        ),
                        title: Text(
                          'Phiếu đã hủy',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                        subtitle: Text(
                          'Không tính vào báo cáo',
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
                          Text(s.code, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          const Text('Tổng tiền bán'),
                          Text(
                            formatVnd(s.totalAmount),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: s.isCancelled
                                  ? scheme.outline
                                  : scheme.primary,
                              decoration: s.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const Divider(height: 24),
                          _InfoRow(Icons.event, formatDateTime(s.saleDate)),
                          _InfoRow(
                            Icons.storefront_outlined,
                            s.buyerName ?? 'Người mua lẻ',
                          ),
                          if (s.note != null) _InfoRow(Icons.notes, s.note!),
                        ],
                      ),
                    ),
                  ),
                  if (!s.isCancelled) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.error,
                              side: BorderSide(color: scheme.error),
                            ),
                            onPressed: () => _cancel(context, ref, s),
                            icon: const Icon(Icons.block),
                            label: const Text('Hủy phiếu'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                context.push(Routes.saleEdit(s.id)),
                            icon: const Icon(Icons.edit),
                            label: const Text('Sửa phiếu'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Tạo lúc ${formatDateTime(s.createdAt.toLocal())}'
                    '${s.updatedAt != s.createdAt ? ' • Cập nhật ${formatDateTime(s.updatedAt.toLocal())}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              );
            },
          ),
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
