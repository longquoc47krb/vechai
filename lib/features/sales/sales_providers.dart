import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/day_group.dart';
import '../../core/utils/text_utils.dart';
import '../../data/repositories/sale_repository.dart';
import '../../domain/sale.dart';
import '../reports/reports_providers.dart';

final salesProvider = FutureProvider<List<Sale>>(
  (ref) => ref.watch(saleRepositoryProvider).getAll(),
);

final saleDetailProvider = FutureProvider.family<Sale?, String>(
  (ref, id) => ref.watch(saleRepositoryProvider).getById(id),
);

void refreshSaleData(WidgetRef ref) {
  ref.invalidate(salesProvider);
  ref.invalidate(saleDetailProvider);
  refreshReports(ref);
}

/// Lọc phiếu bán:
/// - [day]: chỉ lấy phiếu trong ngày đó.
/// - [query]: nếu có chữ số -> tìm theo SỐ TIỀN (gõ "1.200" hoặc "1200" đều
///   khớp 1.200.000đ); đồng thời tìm theo mã phiếu, người mua, ghi chú
///   (không dấu).
List<Sale> filterSales(
  List<Sale> sales, {
  String query = '',
  DateTime? day,
  bool showCancelled = false,
}) {
  final text = normalizeForSearch(query);
  final digits = query.replaceAll(RegExp(r'[^0-9]'), '');

  bool matchesQuery(Sale s) {
    if (text.isEmpty) return true;
    if (digits.isNotEmpty && s.totalAmount.toString().contains(digits)) {
      return true;
    }
    return [s.code, s.buyerName, s.note]
        .whereType<String>()
        .any((field) => normalizeForSearch(field).contains(text));
  }

  return sales.where((s) {
    if (!showCancelled && s.isCancelled) return false;
    if (day != null) {
      final d = s.saleDate;
      if (d.year != day.year || d.month != day.month || d.day != day.day) {
        return false;
      }
    }
    return matchesQuery(s);
  }).toList();
}

List<DayGroup<Sale>> groupSalesByDay(List<Sale> sales) => groupByDay(
  sales,
  dateOf: (s) => s.saleDate,
  amountOf: (s) => s.totalAmount,
  isCancelled: (s) => s.isCancelled,
);
