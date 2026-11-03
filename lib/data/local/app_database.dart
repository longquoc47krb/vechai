import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

/// Quy ước lưu trữ:
/// - Khóa chính: UUID dạng TEXT.
/// - Tiền: INTEGER (VNĐ, không có phần lẻ).
/// - Khối lượng / số lượng: REAL.
/// - Ngày giờ: TEXT theo ISO 8601.
/// - Không xóa cứng giao dịch: dùng cột status ('active' / 'cancelled').
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'vechai.db';
  static const version = 1;

  /// Mở (hoặc tạo mới) database. Test truyền [factory] + [path] riêng.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        default_purchase_price INTEGER NOT NULL DEFAULT 0,
        reference_sale_price INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        purchase_date TEXT NOT NULL,
        seller_name TEXT,
        note TEXT,
        total_amount INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute(
      'CREATE INDEX idx_purchases_date ON purchases(purchase_date)',
    );

    batch.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL REFERENCES purchases(id),
        product_id TEXT NOT NULL REFERENCES products(id),
        product_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute(
      'CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id)',
    );
    batch.execute(
      'CREATE INDEX idx_purchase_items_product ON purchase_items(product_id)',
    );

    batch.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        sale_date TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        buyer_name TEXT,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');

    batch.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        expense_date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');

    // Hàng đợi đồng bộ: mỗi bản ghi thay đổi -> 1 dòng chờ đẩy lên Sheets.
    // Chỉ giữ 1 dòng 'pending' cho mỗi bản ghi (xem SyncQueue.enqueue).
    batch.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status)',
    );

    await batch.commit(noResult: true);

    // onCreate đã chạy sẵn trong 1 transaction -> dùng thẳng db.
    // KHÔNG gọi db.transaction() ở đây: transaction lồng nhau sẽ treo app.
    await seedProducts(db);
  }
}

/// Thời điểm hiện tại theo ISO 8601 (UTC) cho created_at / updated_at.
String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Ngày giao dịch (ngày thu mua, ngày bán...) lưu theo GIỜ ĐỊA PHƯƠNG,
/// ISO 8601 tới giây: "2026-11-03T14:30:00". Cùng 1 định dạng nên so sánh
/// chuỗi >= / < cho ra đúng khoảng thời gian khi lọc báo cáo.
String toDbDate(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}';
}

/// Được gán giá trị thật trong main() sau khi mở database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider chưa được override'),
);
