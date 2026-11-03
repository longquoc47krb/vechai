import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/errors.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/sale.dart';
import '../local/app_database.dart';
import '../local/document_code.dart';
import '../local/sync_queue.dart';

/// Phiếu bán chỉ có tổng tiền. KHÔNG đụng tới kho / mặt hàng.
class SaleRepository {
  SaleRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Tất cả phiếu bán, mới nhất trước.
  Future<List<Sale>> getAll() async {
    final rows = await _db.query(
      'sales',
      orderBy: 'sale_date DESC, created_at DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<Sale?> getById(String id) => _getById(_db, id);

  Future<Sale?> _getById(DatabaseExecutor ex, String id) async {
    final rows = await ex.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Sale.fromMap(rows.first);
  }

  /// Lưu phiếu mới với [id] do form tạo sẵn. Idempotent: lưu lại cùng [id]
  /// thì trả về phiếu cũ, không tạo thêm.
  Future<Sale> create(String id, SaleInput input) async {
    _validate(input);

    await _db.transaction((txn) async {
      if (await _getById(txn, id) != null) return;

      final now = nowIso();
      await txn.insert('sales', {
        'id': id,
        'code': await nextDocumentCode(
          txn,
          table: 'sales',
          prefix: 'BH',
          date: input.saleDate,
        ),
        ..._row(input),
        'status': RecordStatus.active.name,
        'created_at': now,
        'updated_at': now,
      });
      await SyncQueue.enqueue(txn, SyncEntity.sale, id);
    });

    return (await getById(id))!;
  }

  Future<Sale> update(String id, SaleInput input) async {
    _validate(input);

    await _db.transaction((txn) async {
      final current = await _getById(txn, id);
      if (current == null) throw const AppException('Không tìm thấy phiếu');
      if (current.isCancelled) {
        throw const AppException('Phiếu đã hủy, không sửa được');
      }
      await txn.update(
        'sales',
        {..._row(input), 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await SyncQueue.enqueue(txn, SyncEntity.sale, id);
    });

    return (await getById(id))!;
  }

  /// Hủy phiếu: giữ dữ liệu, chỉ đổi trạng thái -> không tính vào báo cáo.
  Future<void> cancel(String id) async {
    await _db.transaction((txn) async {
      final current = await _getById(txn, id);
      if (current == null) throw const AppException('Không tìm thấy phiếu');
      if (current.isCancelled) return;

      await txn.update(
        'sales',
        {'status': RecordStatus.cancelled.name, 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await SyncQueue.enqueue(txn, SyncEntity.sale, id);
    });
  }

  void _validate(SaleInput input) {
    final error = input.validate();
    if (error != null) throw AppException(error);
  }

  Map<String, Object?> _row(SaleInput input) => {
    'sale_date': toDbDate(input.saleDate),
    'total_amount': input.totalAmount,
    'buyer_name': blankToNull(input.buyerName),
    'note': blankToNull(input.note),
  };
}

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(ref.watch(appDatabaseProvider)),
);
