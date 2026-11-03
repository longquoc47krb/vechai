import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/product.dart';
import '../local/app_database.dart';
import '../local/sync_queue.dart';

/// Mọi thao tác đọc / ghi mặt hàng đi qua đây. UI không đụng trực tiếp SQL.
class ProductRepository {
  ProductRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Lấy tất cả mặt hàng: đang kinh doanh trước, rồi theo tên A-Z.
  /// Sắp xếp trong Dart vì SQLite không biết thứ tự tiếng Việt
  /// (ORDER BY name sẽ đẩy "Đồng" xuống cuối).
  Future<List<Product>> getAll() async {
    final rows = await _db.query('products');
    final products = rows.map(Product.fromMap).toList();
    products.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
    });
    return products;
  }

  Future<Product?> getById(String id) async {
    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product> create(ProductInput input) async {
    _validate(input);
    final id = const Uuid().v4();
    final now = nowIso();

    await _db.transaction((txn) async {
      await _ensureUniqueName(txn, input.name);
      await txn.insert('products', {
        'id': id,
        ..._toRow(input),
        'created_at': now,
        'updated_at': now,
      });
      await SyncQueue.enqueue(txn, SyncEntity.product, id);
    });

    return (await getById(id))!;
  }

  Future<Product> update(String id, ProductInput input) async {
    _validate(input);

    await _db.transaction((txn) async {
      await _ensureUniqueName(txn, input.name, exceptId: id);
      final count = await txn.update(
        'products',
        {..._toRow(input), 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw const AppException('Không tìm thấy mặt hàng');
      await SyncQueue.enqueue(txn, SyncEntity.product, id);
    });

    return (await getById(id))!;
  }

  /// Ngừng / mở lại kinh doanh. Không bao giờ xóa mặt hàng vì phiếu cũ
  /// vẫn tham chiếu tới.
  Future<void> setActive(String id, bool isActive) async {
    await _db.transaction((txn) async {
      final count = await txn.update(
        'products',
        {'is_active': isActive ? 1 : 0, 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw const AppException('Không tìm thấy mặt hàng');
      await SyncQueue.enqueue(txn, SyncEntity.product, id);
    });
  }

  void _validate(ProductInput input) {
    final error = input.validate();
    if (error != null) throw AppException(error);
  }

  /// Không cho trùng tên (không phân biệt hoa thường, vẫn phân biệt dấu).
  Future<void> _ensureUniqueName(
    DatabaseExecutor txn,
    String name, {
    String? exceptId,
  }) async {
    String key(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final target = key(name);
    final rows = await txn.query('products', columns: ['id', 'name']);
    final duplicate = rows.any(
      (r) => r['id'] != exceptId && key(r['name'] as String) == target,
    );
    if (duplicate) {
      throw AppException('Mặt hàng "${name.trim()}" đã tồn tại');
    }
  }

  Map<String, Object?> _toRow(ProductInput input) => {
    'name': input.name.trim().replaceAll(RegExp(r'\s+'), ' '),
    'category': input.category,
    'unit': input.unit,
    'default_purchase_price': input.defaultPurchasePrice,
    'reference_sale_price': input.referenceSalePrice,
    'is_active': input.isActive ? 1 : 0,
  };
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(appDatabaseProvider)),
);
