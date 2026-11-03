import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vechai/core/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  test('formatVnd dùng dấu chấm phân cách hàng nghìn', () {
    expect(formatVnd(0), '0đ');
    expect(formatVnd(1200000), '1.200.000đ');
    expect(formatVnd(-500000), '-500.000đ');
  });

  test('formatDate theo dd/MM/yyyy', () {
    expect(formatDate(DateTime(2026, 11, 3)), '03/11/2026');
  });
}
