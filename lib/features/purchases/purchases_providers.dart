import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/day_group.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../domain/purchase.dart';
import '../inventory/inventory_providers.dart';
import '../reports/reports_providers.dart';

final purchasesProvider = FutureProvider<List<Purchase>>(
  (ref) => ref.watch(purchaseRepositoryProvider).getAll(),
);

final purchaseDetailProvider = FutureProvider.family<Purchase?, String>(
  (ref, id) => ref.watch(purchaseRepositoryProvider).getById(id),
);

/// [purchases] phải đã sắp xếp mới nhất trước (như PurchaseRepository.getAll).
List<DayGroup<Purchase>> groupPurchasesByDay(
  List<Purchase> purchases, {
  bool showCancelled = false,
}) => groupByDay(
  purchases.where((p) => showCancelled || !p.isCancelled),
  dateOf: (p) => p.purchaseDate,
  amountOf: (p) => p.totalAmount,
  isCancelled: (p) => p.isCancelled,
);

/// Gọi sau khi thêm / sửa / hủy phiếu để mọi màn hình liên quan
/// (danh sách phiếu, chi tiết, kho hàng) tự tải lại.
void refreshPurchaseData(WidgetRef ref) {
  ref.invalidate(purchasesProvider);
  ref.invalidate(purchaseDetailProvider);
  ref.invalidate(inventoryProvider);
  ref.invalidate(productHistoryProvider);
  refreshReports(ref);
}
