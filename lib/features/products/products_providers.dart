import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/text_utils.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/product.dart';

/// Toàn bộ mặt hàng. Sau khi thêm / sửa gọi ref.invalidate(productsProvider)
/// để danh sách tự tải lại.
final productsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).getAll(),
);

/// Một mặt hàng theo id (dùng cho màn sửa).
final productByIdProvider = FutureProvider.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).getById(id),
);

/// Lọc danh sách theo từ khóa (không dấu), nhóm hàng và trạng thái.
List<Product> filterProducts(
  List<Product> products, {
  String query = '',
  String? category,
  bool showInactive = false,
}) {
  final q = normalizeForSearch(query);
  return products.where((p) {
    if (!showInactive && !p.isActive) return false;
    if (category != null && p.category != category) return false;
    if (q.isNotEmpty && !normalizeForSearch(p.name).contains(q)) return false;
    return true;
  }).toList();
}
