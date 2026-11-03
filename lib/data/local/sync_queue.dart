import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Loại bản ghi cần đồng bộ (trùng tên sheet trên Google Sheets).
class SyncEntity {
  SyncEntity._();

  static const product = 'Products';
  static const purchase = 'Purchases';
  static const sale = 'Sales';
  static const expense = 'Expenses';
}

class SyncQueue {
  SyncQueue._();

  /// Đánh dấu một bản ghi cần đẩy lên Sheets.
  ///
  /// Luôn gọi trong cùng transaction với lệnh ghi dữ liệu, để không bao giờ
  /// có dữ liệu đã lưu mà quên đồng bộ. Lúc đồng bộ sẽ đọc bản mới nhất của
  /// bản ghi, nên mỗi bản ghi chỉ cần 1 dòng chờ.
  static Future<void> enqueue(
    DatabaseExecutor txn,
    String entityType,
    String entityId,
  ) async {
    final now = nowIso();
    final existing = await txn.query(
      'sync_queue',
      columns: ['id'],
      where: "entity_type = ? AND entity_id = ? AND status != 'done'",
      whereArgs: [entityType, entityId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await txn.update(
        'sync_queue',
        {'status': 'pending', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }
    await txn.insert('sync_queue', {
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'status': 'pending',
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
    });
  }
}
