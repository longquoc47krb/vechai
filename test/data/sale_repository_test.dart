import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vechai/core/errors.dart';
import 'package:vechai/data/local/app_database.dart';
import 'package:vechai/data/local/sync_queue.dart';
import 'package:vechai/data/repositories/inventory_repository.dart';
import 'package:vechai/data/repositories/sale_repository.dart';
import 'package:vechai/domain/sale.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late SaleRepository sales;

  setUp(() async {
    database = await openTestDatabase();
    sales = SaleRepository(database);
  });

  tearDown(() => database.close());

  SaleInput input(int amount, {DateTime? date, String? buyer, String? note}) =>
      SaleInput(
        saleDate: date ?? DateTime(2026, 11, 3, 10),
        totalAmount: amount,
        buyerName: buyer,
        note: note,
      );

  String newId() => const Uuid().v4();

  test('Lưu phiếu bán chỉ với tổng tiền', () async {
    final s = await sales.create(
      newId(),
      input(
        1200000,
        buyer: ' Cơ sở thu mua Minh Phát ',
        note: 'Bán hàng tồn trong kho.',
      ),
    );
    expect(s.code, 'BH-20261103-001');
    expect(s.totalAmount, 1200000);
    expect(s.buyerName, 'Cơ sở thu mua Minh Phát');
    expect(s.note, 'Bán hàng tồn trong kho.');
    expect(s.saleDate, DateTime(2026, 11, 3, 10));
  });

  test('Người mua / ghi chú để trống -> null', () async {
    final s = await sales.create(newId(), input(500000, buyer: '   '));
    expect(s.buyerName, isNull);
    expect(s.note, isNull);
  });

  test('Mã phiếu bán tăng dần theo ngày, độc lập với phiếu thu mua', () async {
    final a = await sales.create(newId(), input(1));
    final b = await sales.create(newId(), input(2));
    expect([a.code, b.code], ['BH-20261103-001', 'BH-20261103-002']);
  });

  test('Tổng tiền phải > 0 và không quá lớn', () async {
    expect(() => sales.create(newId(), input(0)), throwsA(isA<AppException>()));
    expect(
      () => sales.create(newId(), input(SaleInput.maxAmount + 1)),
      throwsA(isA<AppException>()),
    );
    expect(await sales.getAll(), isEmpty);
  });

  test('Lưu 2 lần cùng id chỉ tạo 1 phiếu', () async {
    final id = newId();
    await Future.wait([
      sales.create(id, input(1000)),
      sales.create(id, input(1000)),
    ]);
    expect(await sales.getAll(), hasLength(1));
  });

  test('Sửa phiếu bán giữ mã, đổi số tiền', () async {
    final id = newId();
    final created = await sales.create(id, input(1000000));
    final updated = await sales.update(id, input(1500000, buyer: 'Anh Năm'));
    expect(updated.code, created.code);
    expect(updated.totalAmount, 1500000);
    expect(updated.buyerName, 'Anh Năm');
  });

  test('Hủy phiếu: giữ dữ liệu, không sửa được nữa', () async {
    final id = newId();
    await sales.create(id, input(1000000));
    await sales.cancel(id);

    final s = await sales.getById(id);
    expect(s!.isCancelled, isTrue);
    expect(s.totalAmount, 1000000);
    expect(
      () => sales.update(id, input(2000000)),
      throwsA(isA<AppException>()),
    );
  });

  test('Bán hàng KHÔNG ảnh hưởng kho', () async {
    await sales.create(newId(), input(5000000));
    expect(await InventoryRepository(database).summary(), isEmpty);
    expect(await database.db.query('purchase_items'), isEmpty);
  });

  test('Tạo / sửa / hủy đều vào hàng đợi đồng bộ (1 dòng / phiếu)', () async {
    final id = newId();
    await sales.create(id, input(1000));
    await sales.update(id, input(2000));
    await sales.cancel(id);
    final rows = await database.db.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [SyncEntity.sale, id],
    );
    expect(rows, hasLength(1));
  });
}
