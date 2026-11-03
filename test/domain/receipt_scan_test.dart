import 'package:flutter_test/flutter_test.dart';
import 'package:vechai/domain/product.dart';
import 'package:vechai/domain/receipt_scan.dart';

Product _p(String name, {int price = 1000}) => Product(
  id: name,
  name: name,
  category: 'Kim loại',
  unit: 'kg',
  defaultPurchasePrice: price,
  referenceSalePrice: 0,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('parseLooseMoney', () {
    test('số và chuỗi có dấu chấm / đ', () {
      expect(parseLooseMoney(8000), 8000);
      expect(parseLooseMoney('180.000'), 180000);
      expect(parseLooseMoney('8,000đ'), 8000);
      expect(parseLooseMoney(null), isNull);
      expect(parseLooseMoney('abc'), isNull);
    });
    test('viết tắt k / tr', () {
      expect(parseLooseMoney('8k'), 8000);
      expect(parseLooseMoney('7,5k'), 7500);
      expect(parseLooseMoney('1tr2'), 1200000);
      expect(parseLooseMoney('2 triệu'), 2000000);
    });
  });

  test('parseLooseQuantity', () {
    expect(parseLooseQuantity(2.5), 2.5);
    expect(parseLooseQuantity('2,5 kg'), 2.5);
    expect(parseLooseQuantity('10'), 10);
    expect(parseLooseQuantity(0), isNull);
    expect(parseLooseQuantity('kg'), isNull);
  });

  group('ScannedReceipt.fromJson', () {
    test('đọc đủ trường, bỏ dòng không có tên', () {
      final r = ScannedReceipt.fromJson({
        'date': '2026-11-02',
        'seller': ' Chú Ba ',
        'items': [
          {'name': 'Sắt', 'quantity': 12.5, 'unit': 'kg', 'unit_price': 8000},
          {'name': 'Đồng', 'quantity': '2,5', 'unit_price': '180k'},
          {'name': '', 'quantity': 1},
          'rác',
        ],
      });
      expect(r.date, DateTime(2026, 11, 2));
      expect(r.sellerName, 'Chú Ba');
      expect(r.lines, hasLength(2));
      expect(r.lines[1].quantity, 2.5);
      expect(r.lines[1].unitPrice, 180000);
    });

    test('ngày sai / tương lai / quá cũ bị bỏ qua', () {
      expect(ScannedReceipt.fromJson({'date': 'hôm qua'}).date, isNull);
      expect(ScannedReceipt.fromJson({'date': '2099-01-01'}).date, isNull);
      expect(ScannedReceipt.fromJson({'date': '1999-01-01'}).date, isNull);
      expect(ScannedReceipt.fromJson({}).lines, isEmpty);
    });
  });

  test('Cảnh báo khi thành tiền trên phiếu lệch số lượng × đơn giá', () {
    const ok = ScannedLine(name: 'Sắt', quantity: 10, unitPrice: 8000, amount: 80000);
    const bad = ScannedLine(name: 'Sắt', quantity: 10, unitPrice: 8000, amount: 90000);
    expect(ok.amountMismatch, isFalse);
    expect(bad.amountMismatch, isTrue);
    expect(bad.computedAmount, 80000);
  });

  group('matchProduct', () {
    final products = [
      _p('Sắt'),
      _p('Sắt vụn'),
      _p('Đồng'),
      _p('Giấy carton'),
      _p('Nhôm'),
    ];

    test('trùng tên, bỏ dấu, hoa thường', () {
      expect(matchProduct(products, 'DONG')?.name, 'Đồng');
    });
    test('tên mặt hàng nằm trong tên đọc được, ưu tiên tên dài', () {
      expect(matchProduct(products, 'sắt vụn loại 1')?.name, 'Sắt vụn');
      expect(matchProduct(products, 'sắt cây')?.name, 'Sắt');
    });
    test('không khớp nửa chữ ("nhômm" không phải "Nhôm")', () {
      expect(matchProduct(products, 'satthep'), isNull);
    });
    test('tên đọc được nằm trong 1 mặt hàng duy nhất', () {
      expect(matchProduct(products, 'carton')?.name, 'Giấy carton');
    });
    test('không rõ -> null', () {
      expect(matchProduct(products, 'Dây điện'), isNull);
      expect(matchProduct(products, ''), isNull);
    });
  });

  group('ReceiptDraftLine.fromScan', () {
    final products = [_p('Sắt', price: 8000)];

    test('khớp + có số lượng -> sẵn sàng; thiếu giá lấy giá mặc định', () {
      final d = ReceiptDraftLine.fromScan(
        const ScannedLine(name: 'sat', quantity: 3),
        products,
      );
      expect(d.isReady, isTrue);
      expect(d.item!.unitPrice, 8000);
      expect(d.item!.amount, 24000);
    });

    test('có giá trên phiếu thì dùng giá trên phiếu', () {
      final d = ReceiptDraftLine.fromScan(
        const ScannedLine(name: 'Sắt', quantity: 3, unitPrice: 9000),
        products,
      );
      expect(d.item!.unitPrice, 9000);
    });

    test('không khớp hoặc thiếu số lượng -> chưa sẵn sàng', () {
      expect(
        ReceiptDraftLine.fromScan(
          const ScannedLine(name: 'Chì', quantity: 1),
          products,
        ).isReady,
        isFalse,
      );
      expect(
        ReceiptDraftLine.fromScan(const ScannedLine(name: 'Sắt'), products)
            .isReady,
        isFalse,
      );
    });
  });
}
