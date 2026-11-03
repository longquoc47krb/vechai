import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vechai/core/utils/text_utils.dart';
import 'package:vechai/core/widgets/money_field.dart';
import 'package:vechai/domain/product.dart';
import 'package:vechai/features/products/products_providers.dart';

Product _p(String name, String category, {bool active = true}) => Product(
  id: name,
  name: name,
  category: category,
  unit: 'kg',
  defaultPurchasePrice: 0,
  referenceSalePrice: 0,
  isActive: active,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('normalizeForSearch', () {
    test('bỏ dấu, chữ thường, gộp khoảng trắng', () {
      expect(normalizeForSearch('  Sắt  Vụn '), 'sat vun');
      expect(normalizeForSearch('ĐỒNG'), 'dong');
      expect(
        normalizeForSearch('Chai lọ thủy tinh Nhôm Inox ỹ'),
        'chai lo thuy tinh nhom inox y',
      );
    });
  });

  group('Ô nhập tiền', () {
    test('parseMoney', () {
      expect(parseMoney('1.200.000'), 1200000);
      expect(parseMoney(''), isNull);
    });

    test('MoneyInputFormatter tự thêm dấu chấm, bỏ số 0 đầu', () {
      final f = MoneyInputFormatter();
      TextEditingValue type(String s) => f.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: s),
      );
      expect(type('1200000').text, '1.200.000');
      expect(type('0050').text, '50');
      expect(type('abc').text, '');
    });
  });

  group('suggestProducts', () {
    final list = [
      _p('Nhôm', 'Kim loại'),
      _p('Sắt', 'Kim loại'),
      _p('Sắt vụn', 'Kim loại'),
      _p('Inox', 'Kim loại'),
      _p('Nhựa', 'Nhựa'),
    ];
    List<String> names(List<Product> l) => l.map((p) => p.name).toList();

    test('gõ không dấu, tên bắt đầu bằng từ khóa xếp trước', () {
      expect(names(suggestProducts(list, 'sat')), ['Sắt', 'Sắt vụn']);
      expect(names(suggestProducts(list, 'nh')), ['Nhôm', 'Nhựa']);
      // "o" nằm giữa tên: Nhôm, Inox
      expect(names(suggestProducts(list, 'o')), ['Nhôm', 'Inox']);
    });

    test('ô trống -> gợi ý tối đa [limit] mặt hàng', () {
      expect(suggestProducts(list, '', limit: 3), hasLength(3));
    });

    test('hasExactProduct', () {
      expect(hasExactProduct(list, 'sat'), isTrue);
      expect(hasExactProduct(list, 'sat v'), isFalse);
    });
  });

  group('filterProducts', () {
    final list = [
      _p('Sắt', 'Kim loại'),
      _p('Đồng', 'Kim loại'),
      _p('Giấy', 'Giấy'),
      _p('Chì', 'Kim loại', active: false),
    ];

    test('mặc định ẩn hàng ngừng KD', () {
      expect(filterProducts(list), hasLength(3));
      expect(filterProducts(list, showInactive: true), hasLength(4));
    });

    test('tìm không dấu', () {
      expect(filterProducts(list, query: 'dong').single.name, 'Đồng');
      expect(filterProducts(list, query: 'SAT').single.name, 'Sắt');
    });

    test('lọc theo nhóm', () {
      expect(filterProducts(list, category: 'Giấy').single.name, 'Giấy');
    });
  });
}
