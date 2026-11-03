import 'package:flutter/services.dart';

/// Đọc số lượng người dùng gõ, chấp nhận cả "2,5" và "2.5". Rỗng/sai -> null.
double? parseQuantity(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Chỉ cho gõ số, tối đa 1 dấu thập phân (',' hoặc '.') và 3 số lẻ.
class QuantityInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,7}([.,]\d{0,3})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Hiển thị số lượng trong ô nhập: 2.5 -> "2,5", 3.0 -> "3".
String quantityToInput(double q) {
  final text = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  return text.replaceAll('.', ',');
}
