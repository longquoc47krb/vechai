import 'package:intl/intl.dart';

/// Định dạng số tiền VNĐ (lưu bằng số nguyên): 1200000 -> "1.200.000đ".
String formatVnd(int amount) {
  return '${NumberFormat.decimalPattern('vi').format(amount)}đ';
}

/// Định dạng ngày: 03/11/2026.
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

/// Định dạng ngày giờ: 03/11/2026 14:30.
String formatDateTime(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date);
