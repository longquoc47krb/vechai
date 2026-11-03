import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/purchase_repository.dart';
import '../../domain/purchase.dart';
import '../inventory/inventory_providers.dart';

final purchasesProvider = FutureProvider<List<Purchase>>(
  (ref) => ref.watch(purchaseRepositoryProvider).getAll(),
);

final purchaseDetailProvider = FutureProvider.family<Purchase?, String>(
  (ref, id) => ref.watch(purchaseRepositoryProvider).getById(id),
);

/// Nhóm phiếu theo ngày để hiển thị. [activeTotal] chỉ cộng phiếu chưa hủy.
class PurchaseDayGroup {
  PurchaseDayGroup(this.day);

  final DateTime day;
  final List<Purchase> purchases = [];

  int get activeTotal => purchases
      .where((p) => !p.isCancelled)
      .fold(0, (sum, p) => sum + p.totalAmount);
}

/// [purchases] phải đã sắp xếp mới nhất trước (như PurchaseRepository.getAll).
List<PurchaseDayGroup> groupPurchasesByDay(
  List<Purchase> purchases, {
  bool showCancelled = false,
}) {
  final groups = <PurchaseDayGroup>[];
  for (final p in purchases) {
    if (!showCancelled && p.isCancelled) continue;
    final d = p.purchaseDate;
    final day = DateTime(d.year, d.month, d.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(PurchaseDayGroup(day));
    }
    groups.last.purchases.add(p);
  }
  return groups;
}

/// Gọi sau khi thêm / sửa / hủy phiếu để mọi màn hình liên quan
/// (danh sách phiếu, chi tiết, kho hàng) tự tải lại.
void refreshPurchaseData(WidgetRef ref) {
  ref.invalidate(purchasesProvider);
  ref.invalidate(purchaseDetailProvider);
  ref.invalidate(inventoryProvider);
  ref.invalidate(productHistoryProvider);
}
