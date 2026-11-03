import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vechai/core/errors.dart';
import 'package:vechai/data/local/app_database.dart';
import 'package:vechai/data/local/sync_queue.dart';
import 'package:vechai/data/repositories/product_repository.dart';
import 'package:vechai/domain/product.dart';

import '../helpers/test_database.dart';

ProductInput _input(String name, {int buy = 10000, bool isActive = true}) =>
    ProductInput(
      name: name,
      category: 'Kim loại',
      unit: 'kg',
      defaultPurchasePrice: buy,
      referenceSalePrice: buy + 2000,
      isActive: isActive,
    );

void main() {
  late AppDatabase database;
  late ProductRepository repo;

  setUp(() async {
    database = await openTestDatabase();
    repo = ProductRepository(database);
  });

  tearDown(() => database.close());

  Future<int> pendingSyncCount() async => (await database.db.query(
    'sync_queue',
    where: "status = 'pending'",
  )).length;

  test('Tạo sẵn 8 mặt hàng mẫu và đưa vào hàng đợi đồng bộ', () async {
    final all = await repo.getAll();
    expect(all, hasLength(8));
    expect(all.map((p) => p.name).take(4), [
      'Carton',
      'Chai lọ',
      'Đồng',
      'Giấy',
    ]);
    expect(await pendingSyncCount(), 8);
  });

  test('Mở DB từ file: tạo mới 1 lần, mở lại giữ nguyên dữ liệu', () async {
    final dir = await Directory.systemTemp.createTemp('vechai_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'vechai.db');

    final first = await AppDatabase.open(factory: databaseFactoryFfi, path: path)
        .timeout(const Duration(seconds: 10));
    await ProductRepository(first).create(_input('Chì'));
    await first.close();

    final second = await AppDatabase.open(factory: databaseFactoryFfi, path: path)
        .timeout(const Duration(seconds: 10));
    expect(await ProductRepository(second).getAll(), hasLength(9));
    await second.close();
  });

  test('Đủ 6 bảng theo thiết kế', () async {
    final rows = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      rows.map((r) => r['name']),
      containsAll([
        'products',
        'purchases',
        'purchase_items',
        'sales',
        'expenses',
        'sync_queue',
      ]),
    );
  });

  test('Thêm mặt hàng: chuẩn hóa tên, UUID, thời gian ISO 8601', () async {
    final p = await repo.create(_input('  Dây   điện  '));
    expect(p.name, 'Dây điện');
    expect(p.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(p.isActive, isTrue);
    expect(p.createdAt.isUtc, isTrue);
    expect(await pendingSyncCount(), 9);
  });

  test('Không cho trùng tên (không phân biệt hoa thường)', () async {
    expect(
      () => repo.create(_input('sắt')),
      throwsA(isA<AppException>()),
    );
    // Khác dấu là mặt hàng khác -> được phép.
    await repo.create(_input('Sát'));
  });

  test('Dữ liệu không hợp lệ bị từ chối', () async {
    expect(() => repo.create(_input('   ')), throwsA(isA<AppException>()));
    expect(
      () => repo.create(_input('Chì', buy: -1)),
      throwsA(isA<AppException>()),
    );
  });

  test('Sửa mặt hàng, được giữ tên cũ của chính nó', () async {
    final p = await repo.create(_input('Chì'));
    final updated = await repo.update(p.id, _input('chì', buy: 30000));
    expect(updated.name, 'chì');
    expect(updated.defaultPurchasePrice, 30000);
    expect(updated.createdAt, p.createdAt);

    // Đổi sang tên đã có của mặt hàng khác -> lỗi.
    expect(
      () => repo.update(p.id, _input('Đồng')),
      throwsA(isA<AppException>()),
    );
  });

  test('Ngừng kinh doanh không xóa, mở lại được', () async {
    final p = await repo.create(_input('Chì'));
    await repo.setActive(p.id, false);
    expect((await repo.getById(p.id))!.isActive, isFalse);

    await repo.setActive(p.id, true);
    expect((await repo.getById(p.id))!.isActive, isTrue);
    expect(await repo.getAll(), hasLength(9));
  });

  test('Sửa nhiều lần chỉ giữ 1 dòng chờ đồng bộ cho mỗi mặt hàng', () async {
    final p = await repo.create(_input('Chì'));
    await repo.update(p.id, _input('Chì', buy: 1));
    await repo.setActive(p.id, false);

    final rows = await database.db.query(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [SyncEntity.product, p.id],
    );
    expect(rows, hasLength(1));
  });

  test('Ngừng KD mặt hàng không tồn tại -> lỗi', () async {
    expect(
      () => repo.setActive('khong-co', false),
      throwsA(isA<AppException>()),
    );
  });
}
