import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../domain/purchase.dart';
import '../local/app_database.dart';
import '../local/sync_queue.dart';

class PurchaseRepository {
  PurchaseRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Danh sách phiếu, mới nhất trước (không kèm dòng hàng).
  Future<List<Purchase>> getAll() async {
    final rows = await _db.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM purchase_items i
                   WHERE i.purchase_id = p.id) AS item_count
      FROM purchases p
      ORDER BY p.purchase_date DESC, p.created_at DESC
    ''');
    return rows.map(Purchase.fromMap).toList();
  }

  /// Chi tiết 1 phiếu kèm các dòng hàng.
  Future<Purchase?> getById(String id) => _getById(_db, id);

  Future<Purchase?> _getById(DatabaseExecutor ex, String id) async {
    final rows = await ex.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await ex.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    return Purchase.fromMap(
      rows.first,
      items: items.map(PurchaseItem.fromMap).toList(),
    );
  }

  /// Lưu phiếu mới với [id] do form tạo sẵn.
  ///
  /// Idempotent: nếu phiếu [id] đã tồn tại (bấm Lưu 2 lần, mạng chập chờn...)
  /// thì trả về phiếu cũ, không tạo thêm.
  Future<Purchase> create(String id, PurchaseInput input) async {
    _validate(input);

    await _db.transaction((txn) async {
      if (await _getById(txn, id) != null) return;

      final now = nowIso();
      await txn.insert('purchases', {
        'id': id,
        'code': await _nextCode(txn, input.purchaseDate),
        ..._headerRow(input),
        'status': RecordStatus.active.name,
        'created_at': now,
        'updated_at': now,
      });
      await _insertItems(txn, id, input.items, now);
      await SyncQueue.enqueue(txn, SyncEntity.purchase, id);
    });

    return (await getById(id))!;
  }

  /// Sửa phiếu: cập nhật thông tin chung, thay toàn bộ dòng hàng,
  /// tính lại tổng tiền. Kho hàng tự đúng vì được tính từ dữ liệu phiếu.
  Future<Purchase> update(String id, PurchaseInput input) async {
    _validate(input);

    await _db.transaction((txn) async {
      final current = await _getById(txn, id);
      if (current == null) throw const AppException('Không tìm thấy phiếu');
      if (current.isCancelled) {
        throw const AppException('Phiếu đã hủy, không sửa được');
      }

      final now = nowIso();
      await txn.update(
        'purchases',
        {..._headerRow(input), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [id],
      );
      await _insertItems(txn, id, input.items, now);
      await SyncQueue.enqueue(txn, SyncEntity.purchase, id);
    });

    return (await getById(id))!;
  }

  /// Hủy phiếu: giữ nguyên dữ liệu, chỉ đổi trạng thái. Phiếu hủy không
  /// được tính vào kho và báo cáo.
  Future<void> cancel(String id) async {
    await _db.transaction((txn) async {
      final current = await _getById(txn, id);
      if (current == null) throw const AppException('Không tìm thấy phiếu');
      if (current.isCancelled) return;

      await txn.update(
        'purchases',
        {'status': RecordStatus.cancelled.name, 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await SyncQueue.enqueue(txn, SyncEntity.purchase, id);
    });
  }

  void _validate(PurchaseInput input) {
    final error = input.validate();
    if (error != null) throw AppException(error);
  }

  Map<String, Object?> _headerRow(PurchaseInput input) => {
    'purchase_date': toDbDate(input.purchaseDate),
    'seller_name': _blankToNull(input.sellerName),
    'note': _blankToNull(input.note),
    'total_amount': input.totalAmount,
  };

  Future<void> _insertItems(
    Transaction txn,
    String purchaseId,
    List<PurchaseItemInput> items,
    String now,
  ) async {
    for (final (index, item) in items.indexed) {
      await txn.insert('purchase_items', {
        'id': const Uuid().v4(),
        'purchase_id': purchaseId,
        'product_id': item.productId,
        'product_name': item.productName,
        'unit': item.unit,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'amount': item.amount,
        'sort_order': index,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Mã phiếu theo ngày thu mua: TM-yyyyMMdd-001, 002...
  Future<String> _nextCode(Transaction txn, DateTime date) async {
    final day = toDbDate(date).substring(0, 10).replaceAll('-', '');
    final prefix = 'TM-$day-';
    final rows = await txn.rawQuery(
      'SELECT MAX(code) AS max_code FROM purchases WHERE code LIKE ?',
      ['$prefix%'],
    );
    final maxCode = rows.first['max_code'] as String?;
    final next = maxCode == null
        ? 1
        : int.parse(maxCode.substring(prefix.length)) + 1;
    return '$prefix${next.toString().padLeft(3, '0')}';
  }

  String? _blankToNull(String? s) {
    final trimmed = s?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(ref.watch(appDatabaseProvider)),
);
