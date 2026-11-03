import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../domain/product.dart';
import 'products_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';
  String? _category;
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mặt hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.productNew),
        icon: const Icon(Icons.add),
        label: const Text('Thêm mặt hàng'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm mặt hàng (gõ không dấu cũng được)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Ngừng KD'),
                  avatar: const Icon(Icons.visibility_off_outlined, size: 18),
                  selected: _showInactive,
                  onSelected: (v) => setState(() => _showInactive = v),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in ProductOptions.categories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (all) {
                final items = filterProducts(
                  all,
                  query: _query,
                  category: _category,
                  showInactive: _showInactive,
                );
                if (items.isEmpty) {
                  return const Center(child: Text('Không có mặt hàng phù hợp'));
                }
                return ListView.separated(
                  // Chừa chỗ cho nút "Thêm mặt hàng" không che dòng cuối.
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ProductTile(product: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: p.isActive
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          child: Text(
            p.name.characters.first.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: p.isActive ? scheme.onPrimaryContainer : scheme.outline,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: p.isActive ? null : scheme.outline,
                ),
              ),
            ),
            if (!p.isActive) ...[
              const SizedBox(width: 8),
              Text(
                'Ngừng KD',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ],
          ],
        ),
        // Wrap: nếu không đủ chỗ thì cả cụm "Bán TK: ..." xuống dòng,
        // không bị cắt giữa chừng.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.category),
            Wrap(
              spacing: 12,
              children: [
                Text('Mua: ${formatVnd(p.defaultPurchasePrice)}/${p.unit}'),
                Text('Bán TK: ${formatVnd(p.referenceSalePrice)}/${p.unit}'),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.productEdit(p.id)),
      ),
    );
  }
}
