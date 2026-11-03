import 'package:intl/intl.dart';

/// Định dạng số tiền VNĐ (lưu bằng số nguyên): 1200000 -> "1.200.000đ".
String formatVnd(int amount) {
  return '${NumberFormat.decimalPattern('vi').format(amount)}đ';
}

/// Số tiền rút gọn cho trục biểu đồ: 1.200.000 -> "1,2tr", 850.000 -> "850k",
/// 2.500.000.000 -> "2,5 tỷ".
String formatCompactVnd(num amount) {
  final sign = amount < 0 ? '-' : '';
  final a = amount.abs();
  String n(num v) => NumberFormat('#,##0.#', 'vi').format(v);
  if (a >= 1e9) return '$sign${n(a / 1e9)} tỷ';
  if (a >= 1e6) return '$sign${n(a / 1e6)}tr';
  if (a >= 1e3) return '$sign${n(a / 1e3)}k';
  return '$sign${n(a)}';
}

/// Định dạng số lượng / khối lượng, tối đa 3 số lẻ: 2.5 -> "2,5",
/// 1200 -> "1.200".
String formatQuantity(double quantity) =>
    NumberFormat('#,##0.###', 'vi').format(quantity);

/// Định dạng ngày: 03/11/2026.
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

/// Định dạng ngày giờ: 03/11/2026 14:30.
String formatDateTime(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date);
