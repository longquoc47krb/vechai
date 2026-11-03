import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vechai/core/utils/formatters.dart';
import 'package:vechai/core/widgets/quantity_field.dart';
import 'package:vechai/domain/inventory.dart';
import 'package:vechai/domain/purchase.dart';
import 'package:vechai/features/purchases/purchases_providers.dart';

PurchaseItemInput _line(double q, int price, {String name = 'Sắt'}) =>
    PurchaseItemInput(
      productId: name,
      productName: name,
      unit: 'kg',
      quantity: q,
      unitPrice: price,
    );

Purchase _purchase(String id, DateTime date, int total, {bool cancelled = false}) =>
    Purchase(
      id: id,
      code: id,
      purchaseDate: date,
      sellerName: null,
      note: null,
      totalAmount: total,
      status: cancelled ? RecordStatus.cancelled : RecordStatus.active,
      itemCount: 1,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Tính tiền', () {
    test('Thành tiền = Số lượng × Đơn giá, làm tròn tới đồng', () {
      expect(calcLineAmount(2.5, 8000), 20000);
      expect(calcLineAmount(0.333, 10000), 3330);
      expect(calcLineAmount(1.005, 1000), 1005);
      expect(calcLineAmount(3, 0), 0);
    });

    test('Tổng phiếu = tổng thành tiền các dòng', () {
      final input = PurchaseInput(
        purchaseDate: DateTime(2026, 11, 3),
        items: [_line(10, 8000), _line(2.5, 180000, name: 'Đồng')],
      );
      expect(input.totalAmount, 80000 + 450000);
    });
  });

  group('Kiểm tra phiếu', () {
    PurchaseInput input(List<PurchaseItemInput> items) =>
        PurchaseInput(purchaseDate: DateTime(2026), items: items);

    test('phải có ít nhất 1 dòng', () {
      expect(input([]).validate(), isNotNull);
    });
    test('số lượng phải > 0', () {
      expect(input([_line(0, 1000)]).validate(), contains('số lượng'));
      expect(input([_line(-1, 1000)]).validate(), isNotNull);
    });
    test('đơn giá không âm', () {
      expect(input([_line(1, -5)]).validate(), contains('đơn giá'));
    });
    test('hợp lệ', () {
      expect(input([_line(1.5, 0)]).validate(), isNull);
    });
  });

  group('Số lượng', () {
    test('parseQuantity nhận cả dấu phẩy và dấu chấm', () {
      expect(parseQuantity('2,5'), 2.5);
      expect(parseQuantity('2.5'), 2.5);
      expect(parseQuantity(''), isNull);
    });

    test('QuantityInputFormatter chặn ký tự lạ và quá 3 số lẻ', () {
      final f = QuantityInputFormatter();
      String type(String old, String next) => f
          .formatEditUpdate(
            TextEditingValue(text: old),
            TextEditingValue(text: next),
          )
          .text;
      expect(type('2', '2,'), '2,');
      expect(type('2,5', '2,5a'), '2,5');
      expect(type('2,125', '2,1255'), '2,125');
      expect(type('2,5', '2,5,'), '2,5');
    });

    test('hiển thị', () {
      expect(formatQuantity(2.5), '2,5');
      expect(formatQuantity(1200), '1.200');
      expect(quantityToInput(3), '3');
      expect(quantityToInput(2.25), '2,25');
    });
  });

  test('Nhóm phiếu theo ngày, tổng ngày bỏ qua phiếu hủy', () {
    final list = [
      _purchase('a', DateTime(2026, 11, 3, 15), 100),
      _purchase('b', DateTime(2026, 11, 3, 9), 50, cancelled: true),
      _purchase('c', DateTime(2026, 11, 2, 8), 70),
    ];

    final hidden = groupPurchasesByDay(list);
    expect(hidden, hasLength(2));
    expect(hidden.first.items.map((p) => p.id), ['a']);

    final shown = groupPurchasesByDay(list, showCancelled: true);
    expect(shown.first.items, hasLength(2));
    expect(shown.first.activeTotal, 100);
    expect(shown.last.day, DateTime(2026, 11, 2));
  });

  test('Khoảng thời gian xem kho', () {
    final now = DateTime(2026, 12, 15, 10);
    expect(InventoryPeriod.all.range(now), (null, null));
    expect(InventoryPeriod.thisMonth.range(now), (
      DateTime(2026, 12),
      DateTime(2027, 1),
    ));
    expect(InventoryPeriod.thisYear.range(now), (
      DateTime(2026),
      DateTime(2027),
    ));
  });
}
