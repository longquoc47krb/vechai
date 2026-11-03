import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/inventory.dart';
import '../local/app_database.dart';

/// Kho hàng = tổng hợp từ các phiếu thu mua CHƯA HỦY.
/// Không lưu số tồn riêng, nên sửa / hủy phiếu thì số liệu tự đúng.
/// Không trừ kho khi bán vì phiếu bán chỉ có tổng tiền.
class InventoryRepository {
  InventoryRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Tổng hợp theo mặt hàng trong khoảng [from, to) (null = không giới hạn),
  /// sắp xếp theo giá trị thu mua giảm dần.
  Future<List<InventoryRow>> summary({DateTime? from, DateTime? to}) async {
    final where = ["p.status = 'active'"];
    final args = <Object>[];
    if (from != null) {
      where.add('p.purchase_date >= ?');
      args.add(toDbDate(from));
    }
    if (to != null) {
      where.add('p.purchase_date < ?');
      args.add(toDbDate(to));
    }

    // Gom theo mặt hàng + đơn vị (phòng khi đơn vị của mặt hàng bị đổi).
    final rows = await _db.rawQuery('''
      SELECT i.product_id,
             COALESCE(pr.name, MAX(i.product_name)) AS product_name,
             COALESCE(pr.category, '') AS category,
             i.unit,
             SUM(i.quantity) AS total_quantity,
             SUM(i.amount) AS total_amount,
             COUNT(DISTINCT p.id) AS purchase_count,
             MAX(p.purchase_date) AS last_purchase_date
      FROM purchase_items i
      JOIN purchases p ON p.id = i.purchase_id
      LEFT JOIN products pr ON pr.id = i.product_id
      WHERE ${where.join(' AND ')}
      GROUP BY i.product_id, i.unit
      ORDER BY total_amount DESC
    ''', args);

    return rows
        .map(
          (r) => InventoryRow(
            productId: r['product_id'] as String,
            productName: r['product_name'] as String,
            category: r['category'] as String,
            unit: r['unit'] as String,
            totalQuantity: (r['total_quantity'] as num).toDouble(),
            totalAmount: r['total_amount'] as int,
            purchaseCount: r['purchase_count'] as int,
            lastPurchaseDate: DateTime.parse(
              r['last_purchase_date'] as String,
            ),
          ),
        )
        .toList();
  }

  /// Lịch sử nhập hàng của 1 mặt hàng, mới nhất trước.
  Future<List<ProductPurchaseEntry>> history(String productId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.id AS purchase_id, p.code, p.purchase_date, p.seller_name,
             i.quantity, i.unit, i.unit_price, i.amount
      FROM purchase_items i
      JOIN purchases p ON p.id = i.purchase_id
      WHERE i.product_id = ? AND p.status = 'active'
      ORDER BY p.purchase_date DESC, p.created_at DESC
    ''',
      [productId],
    );

    return rows
        .map(
          (r) => ProductPurchaseEntry(
            purchaseId: r['purchase_id'] as String,
            purchaseCode: r['code'] as String,
            purchaseDate: DateTime.parse(r['purchase_date'] as String),
            sellerName: r['seller_name'] as String?,
            quantity: (r['quantity'] as num).toDouble(),
            unit: r['unit'] as String,
            unitPrice: r['unit_price'] as int,
            amount: r['amount'] as int,
          ),
        )
        .toList();
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(appDatabaseProvider)),
);
