import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vechai/core/errors.dart';
import 'package:vechai/data/local/app_database.dart';
import 'package:vechai/data/local/sync_queue.dart';
import 'package:vechai/data/repositories/inventory_repository.dart';
import 'package:vechai/data/repositories/product_repository.dart';
import 'package:vechai/data/repositories/purchase_repository.dart';
import 'package:vechai/domain/product.dart';
import 'package:vechai/domain/purchase.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late PurchaseRepository purchases;
  late InventoryRepository inventory;
  late Product sat;
  late Product dong;

  setUp(() async {
    database = await openTestDatabase();
    purchases = PurchaseRepository(database);
    inventory = InventoryRepository(database);
    final products = await ProductRepository(database).getAll();
    sat = products.firstWhere((p) => p.name == 'Sắt');
    dong = products.firstWhere((p) => p.name == 'Đồng');
  });

  tearDown(() => database.close());

  PurchaseItemInput line(Product p, double q, int price) => PurchaseItemInput(
    productId: p.id,
    productName: p.name,
    unit: p.unit,
    quantity: q,
    unitPrice: price,
  );

  PurchaseInput input(
    List<PurchaseItemInput> items, {
    DateTime? date,
    String? seller,
  }) => PurchaseInput(
    purchaseDate: date ?? DateTime(2026, 11, 3, 9, 30),
    sellerName: seller,
    items: items,
  );

  String newId() => const Uuid().v4();

  test('Lưu phiếu nhiều dòng: tính tổng, mã phiếu, lưu đủ chi tiết', () async {
    final p = await purchases.create(
      newId(),
      input([line(sat, 10, 8000), line(dong, 2.5, 180000)], seller: ' Chú Ba '),
    );

    expect(p.code, 'TM-20261103-001');
    expect(p.totalAmount, 80000 + 450000);
    expect(p.sellerName, 'Chú Ba');
    expect(p.note, isNull);
    expect(p.items.map((i) => i.productName), ['Sắt', 'Đồng']);
    expect(p.items.last.quantity, 2.5);
    expect(p.items.last.amount, 450000);
    expect(p.purchaseDate, DateTime(2026, 11, 3, 9, 30));
  });

  test('Mã phiếu tăng dần theo từng ngày', () async {
    final a = await purchases.create(newId(), input([line(sat, 1, 1)]));
    final b = await purchases.create(newId(), input([line(sat, 1, 1)]));
    final c = await purchases.create(
      newId(),
      input([line(sat, 1, 1)], date: DateTime(2026, 11, 4)),
    );
    expect([a.code, b.code, c.code], [
      'TM-20261103-001',
      'TM-20261103-002',
      'TM-20261104-001',
    ]);
  });

  test('Lưu 2 lần cùng id chỉ tạo 1 phiếu (chống lưu trùng)', () async {
    final id = newId();
    final data = input([line(sat, 10, 8000)]);
    await Future.wait([purchases.create(id, data), purchases.create(id, data)]);
    await purchases.create(id, data);

    expect(await purchases.getAll(), hasLength(1));
    final items = await database.db.query('purchase_items');
    expect(items, hasLength(1));
  });

  test('Lỗi giữa chừng -> không lưu gì (transaction)', () async {
    final bad = PurchaseItemInput(
      productId: 'khong-ton-tai',
      productName: 'Ma',
      unit: 'kg',
      quantity: 1,
      unitPrice: 1000,
    );
    await expectLater(
      purchases.create(newId(), input([line(sat, 1, 1000), bad])),
      throwsA(anything),
    );
    expect(await database.db.query('purchases'), isEmpty);
    expect(await database.db.query('purchase_items'), isEmpty);
  });

  test('Dữ liệu không hợp lệ bị từ chối', () async {
    expect(
      () => purchases.create(newId(), input([])),
      throwsA(isA<AppException>()),
    );
    expect(
      () => purchases.create(newId(), input([line(sat, 0, 1000)])),
      throwsA(isA<AppException>()),
    );
  });

  test('Sửa phiếu: thay dòng hàng, tính lại tổng, giữ mã phiếu', () async {
    final id = newId();
    final created = await purchases.create(
      id,
      input([line(sat, 10, 8000), line(dong, 1, 180000)]),
    );
    final updated = await purchases.update(
      id,
      input([line(sat, 12, 8500)], seller: 'Cô Tư'),
    );

    expect(updated.code, created.code);
    expect(updated.items, hasLength(1));
    expect(updated.totalAmount, 102000);
    expect(updated.sellerName, 'Cô Tư');
    expect(await database.db.query('purchase_items'), hasLength(1));
  });

  test('Kho hàng: cộng dồn, cập nhật khi sửa, bỏ phiếu hủy', () async {
    final id1 = newId();
    final id2 = newId();
    await purchases.create(id1, input([line(sat, 10, 8000)]));
    await purchases.create(
      id2,
      input([line(sat, 5.5, 9000), line(dong, 2, 180000)]),
    );

    var rows = await inventory.summary();
    final satRow = rows.firstWhere((r) => r.productId == sat.id);
    expect(satRow.totalQuantity, 15.5);
    expect(satRow.totalAmount, 80000 + 49500);
    expect(satRow.purchaseCount, 2);
    expect(satRow.averagePrice, (129500 / 15.5).round());
    // Sắp xếp theo giá trị giảm dần: Đồng (360k) trước Sắt (129.5k).
    expect(rows.first.productId, dong.id);

    // Sửa phiếu 1: 10kg -> 20kg
    await purchases.update(id1, input([line(sat, 20, 8000)]));
    rows = await inventory.summary();
    expect(rows.firstWhere((r) => r.productId == sat.id).totalQuantity, 25.5);

    // Hủy phiếu 2 -> chỉ còn phiếu 1, Đồng biến mất
    await purchases.cancel(id2);
    rows = await inventory.summary();
    expect(rows, hasLength(1));
    expect(rows.single.totalQuantity, 20);
    expect((await inventory.history(sat.id)), hasLength(1));
  });

  test('Kho hàng lọc theo khoảng thời gian', () async {
    await purchases.create(
      newId(),
      input([line(sat, 1, 1000)], date: DateTime(2026, 10, 31, 23, 59)),
    );
    await purchases.create(
      newId(),
      input([line(sat, 2, 1000)], date: DateTime(2026, 11, 1)),
    );
    final nov = await inventory.summary(
      from: DateTime(2026, 11),
      to: DateTime(2026, 12),
    );
    expect(nov.single.totalQuantity, 2);
  });

  test('Phiếu đã hủy không sửa được; hủy lại không lỗi', () async {
    final id = newId();
    await purchases.create(id, input([line(sat, 1, 1000)]));
    await purchases.cancel(id);
    await purchases.cancel(id);

    final p = await purchases.getById(id);
    expect(p!.isCancelled, isTrue);
    expect(p.items, hasLength(1), reason: 'Hủy không xóa dữ liệu');
    expect(
      () => purchases.update(id, input([line(sat, 2, 1000)])),
      throwsA(isA<AppException>()),
    );
  });

  test('Mỗi thay đổi phiếu đều vào hàng đợi đồng bộ', () async {
    final id = newId();
    await purchases.create(id, input([line(sat, 1, 1000)]));
    await purchases.update(id, input([line(sat, 2, 1000)]));
    await purchases.cancel(id);

    final rows = await database.db.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [SyncEntity.purchase, id],
    );
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'pending');
  });
}
