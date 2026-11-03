import 'package:intl/intl.dart';

/// Định dạng số tiền VNĐ (lưu bằng số nguyên): 1200000 -> "1.200.000đ".
String formatVnd(int amount) {
  return '${NumberFormat.decimalPattern('vi').format(amount)}đ';
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
