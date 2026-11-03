import 'package:flutter_test/flutter_test.dart';
import 'package:vechai/domain/sale.dart';
import 'package:vechai/features/sales/sales_providers.dart';

Sale _sale(
  String code,
  int amount,
  DateTime date, {
  String? buyer,
  String? note,
  bool cancelled = false,
}) => Sale(
  id: code,
  code: code,
  saleDate: date,
  totalAmount: amount,
  buyerName: buyer,
  note: note,
  status: cancelled ? RecordStatus.cancelled : RecordStatus.active,
  createdAt: date,
  updatedAt: date,
);

void main() {
  test('SaleInput.validate', () {
    SaleInput i(int a) => SaleInput(saleDate: DateTime(2026), totalAmount: a);
    expect(i(0).validate(), isNotNull);
    expect(i(-1).validate(), isNotNull);
    expect(i(1200000).validate(), isNull);
    expect(i(SaleInput.maxAmount + 1).validate(), isNotNull);
  });

  group('filterSales', () {
    final list = [
      _sale('BH-1', 1200000, DateTime(2026, 11, 3, 15), buyer: 'Minh Phát'),
      _sale('BH-2', 450000, DateTime(2026, 11, 3, 9), note: 'Bán giấy vụn'),
      _sale('BH-3', 3000000, DateTime(2026, 11, 2), cancelled: true),
    ];

    List<String> codes(List<Sale> s) => s.map((e) => e.code).toList();

    test('mặc định ẩn phiếu hủy', () {
      expect(codes(filterSales(list)), ['BH-1', 'BH-2']);
      expect(filterSales(list, showCancelled: true), hasLength(3));
    });

    test('tìm theo số tiền, có hoặc không có dấu chấm', () {
      expect(codes(filterSales(list, query: '1.200')), ['BH-1']);
      expect(codes(filterSales(list, query: '450000')), ['BH-2']);
    });

    test('tìm theo người mua / ghi chú không dấu', () {
      expect(codes(filterSales(list, query: 'minh phat')), ['BH-1']);
      expect(codes(filterSales(list, query: 'giay')), ['BH-2']);
    });

    test('lọc theo ngày', () {
      expect(
        codes(
          filterSales(list, day: DateTime(2026, 11, 2), showCancelled: true),
        ),
        ['BH-3'],
      );
    });
  });

  test('Nhóm theo ngày, tổng ngày bỏ phiếu hủy', () {
    final groups = groupSalesByDay([
      _sale('a', 100, DateTime(2026, 11, 3, 10)),
      _sale('b', 50, DateTime(2026, 11, 3, 8), cancelled: true),
      _sale('c', 70, DateTime(2026, 11, 1)),
    ]);
    expect(groups, hasLength(2));
    expect(groups.first.items, hasLength(2));
    expect(groups.first.activeTotal, 100);
  });
}
