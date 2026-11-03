import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vechai/domain/product.dart';
import 'package:vechai/domain/receipt_scan.dart';
import 'package:vechai/features/purchases/receipt_review_screen.dart';

// Ảnh PNG 1x1 hợp lệ để Image.memory không lỗi.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Product _p(String name, int price) => Product(
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
  setUpAll(() => initializeDateFormatting('vi'));

  testWidgets('Dòng chưa khớp chặn nút thêm; bỏ chọn dòng đó thì thêm được', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    ReceiptReviewResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReceiptReviewScreen(
                      image: _png,
                      products: [_p('Sắt', 8000), _p('Đồng', 180000)],
                      receipt: ScannedReceipt(
                        date: DateTime(2026, 11, 2),
                        sellerName: 'Chú Ba',
                        lines: const [
                          ScannedLine(name: 'sat vun', quantity: 10, unitPrice: 8500),
                          ScannedLine(name: 'Dây điện', quantity: 2, unitPrice: 15000),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    // Dòng 1 tự khớp "Sắt" và giữ giá trên phiếu; dòng 2 chưa khớp.
    expect(find.text('10 kg × 8.500đ = 85.000đ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chưa khớp mặt hàng – chạm để chọn'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa khớp mặt hàng – chạm để chọn'), findsOneWidget);
    final addButton = find.widgetWithText(FilledButton, 'Thêm 2 dòng vào phiếu • 85.000đ');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    // Bỏ dòng "Dây điện".
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm 1 dòng vào phiếu • 85.000đ'));
    await tester.pumpAndSettle();

    expect(result!.items.single.productName, 'Sắt');
    expect(result!.items.single.unitPrice, 8500);
    expect(result!.date, DateTime(2026, 11, 2));
    expect(result!.sellerName, 'Chú Ba');
  });
}
