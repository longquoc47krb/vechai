import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Đọc chuỗi tiền đã định dạng ("1.200.000") thành số nguyên. Rỗng -> null.
int? parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

/// Định dạng số khi đang gõ: 1200000 -> 1.200.000
String formatMoneyInput(int value) =>
    NumberFormat.decimalPattern('vi').format(value);

class MoneyInputFormatter extends TextInputFormatter {
  static const maxDigits = 12; // tối đa 999 tỷ

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > maxDigits) return oldValue;
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = formatMoneyInput(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Ô nhập số tiền VNĐ: bàn phím số, tự thêm dấu chấm, hậu tố "đ".
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.helperText,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final String? helperText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: [MoneyInputFormatter()],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        suffixText: 'đ',
        helperText: helperText,
      ),
      validator: (value) {
        if (required && parseMoney(value ?? '') == null) {
          return 'Vui lòng nhập ${label.toLowerCase()}';
        }
        return null;
      },
    );
  }
}
