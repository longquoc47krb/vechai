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

/// Gợi ý mặt hàng khi gõ (không dấu, không phân biệt hoa thường).
/// Mặt hàng có tên BẮT ĐẦU bằng từ khóa xếp trước, rồi tới tên CHỨA từ khóa.
List<Product> suggestProducts(
  List<Product> products,
  String query, {
  int limit = 6,
}) {
  final q = normalizeForSearch(query);
  final starts = <Product>[];
  final contains = <Product>[];
  for (final p in products) {
    final name = normalizeForSearch(p.name);
    if (q.isEmpty || name.startsWith(q)) {
      starts.add(p);
    } else if (name.contains(q)) {
      contains.add(p);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// true nếu đã có mặt hàng trùng tên với [query] (bỏ dấu, hoa thường).
bool hasExactProduct(List<Product> products, String query) {
  final q = normalizeForSearch(query);
  return products.any((p) => normalizeForSearch(p.name) == q);
}

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
