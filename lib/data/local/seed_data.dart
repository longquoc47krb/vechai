import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'sync_queue.dart';

/// Mặt hàng mẫu tạo sẵn khi cài app lần đầu. Giá chỉ để tham khảo,
/// người dùng tự sửa lại theo giá thực tế.
const _seedProducts = [
  // (tên, nhóm, đơn vị, giá thu mua, giá bán tham khảo)
  ('Sắt', 'Kim loại', 'kg', 8000, 9500),
  ('Đồng', 'Kim loại', 'kg', 180000, 200000),
  ('Nhôm', 'Kim loại', 'kg', 40000, 45000),
  ('Inox', 'Kim loại', 'kg', 25000, 28000),
  ('Nhựa', 'Nhựa', 'kg', 5000, 7000),
  ('Giấy', 'Giấy', 'kg', 4000, 5000),
  ('Carton', 'Giấy', 'kg', 3500, 4500),
  ('Chai lọ', 'Thủy tinh', 'kg', 1000, 1500),
];

Future<void> seedProducts(DatabaseExecutor txn) async {
  final now = nowIso();
  for (final (name, category, unit, buy, sell) in _seedProducts) {
    final id = const Uuid().v4();
    await txn.insert('products', {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'default_purchase_price': buy,
      'reference_sale_price': sell,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await SyncQueue.enqueue(txn, SyncEntity.product, id);
  }
}
