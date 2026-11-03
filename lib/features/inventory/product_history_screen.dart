import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import 'inventory_providers.dart';

/// Lịch sử nhập hàng của 1 mặt hàng (chỉ phiếu chưa hủy).
class ProductHistoryScreen extends ConsumerWidget {
  const ProductHistoryScreen({
    super.key,
    required this.productId,
    this.productName,
  });

  final String productId;
  final String? productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productHistoryProvider(productId));

    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử nhập: ${productName ?? ''}')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Chưa có lần nhập nào'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => context.push(Routes.purchaseDetail(e.purchaseId)),
                  title: Text(
                    '${formatQuantity(e.quantity)} ${e.unit} × '
                    '${formatVnd(e.unitPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${formatDateTime(e.purchaseDate)} • ${e.purchaseCode}'
                    '${e.sellerName != null ? '\n${e.sellerName}' : ''}',
                  ),
                  isThreeLine: e.sellerName != null,
                  trailing: Text(
                    formatVnd(e.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
