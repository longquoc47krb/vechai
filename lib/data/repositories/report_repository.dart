import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/report.dart';
import '../local/app_database.dart';

/// Báo cáo luôn TÍNH LẠI từ phiếu thu mua / bán chưa hủy, không lưu sẵn số
/// tổng nào -> sửa hay hủy phiếu thì báo cáo tự đúng.
class ReportRepository {
  ReportRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Tổng trong [from, to).
  Future<ReportTotals> totals(DateTime from, DateTime to) async {
    final (purchaseTotal, purchaseCount) = await _sum(
      'purchases',
      'purchase_date',
      from,
      to,
    );
    final (saleTotal, saleCount) = await _sum('sales', 'sale_date', from, to);
    return ReportTotals(
      purchaseTotal: purchaseTotal,
      saleTotal: saleTotal,
      purchaseCount: purchaseCount,
      saleCount: saleCount,
    );
  }

  /// Tổng cả kỳ + chia theo từng ngày / tháng để vẽ biểu đồ.
  Future<ReportData> report(ReportPeriod period) async {
    final byMonth = period.type == ReportPeriodType.year;
    final purchases = await _grouped(
      'purchases',
      'purchase_date',
      period,
      byMonth,
    );
    final sales = await _grouped('sales', 'sale_date', period, byMonth);

    String key(DateTime d) => toDbDate(d).substring(0, byMonth ? 7 : 10);
    final buckets = [
      for (final range in period.buckets)
        ReportBucket(
          range,
          ReportTotals(
            purchaseTotal: purchases[key(range.start)]?.$1 ?? 0,
            purchaseCount: purchases[key(range.start)]?.$2 ?? 0,
            saleTotal: sales[key(range.start)]?.$1 ?? 0,
            saleCount: sales[key(range.start)]?.$2 ?? 0,
          ),
        ),
    ];

    return ReportData(
      totals: ReportTotals(
        purchaseTotal: buckets.fold(0, (s, b) => s + b.totals.purchaseTotal),
        saleTotal: buckets.fold(0, (s, b) => s + b.totals.saleTotal),
        purchaseCount: buckets.fold(0, (s, b) => s + b.totals.purchaseCount),
        saleCount: buckets.fold(0, (s, b) => s + b.totals.saleCount),
      ),
      buckets: buckets,
    );
  }

  Future<(int, int)> _sum(
    String table,
    String dateColumn,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS total, COUNT(*) AS cnt
      FROM $table
      WHERE status = 'active' AND $dateColumn >= ? AND $dateColumn < ?
    ''',
      [toDbDate(from), toDbDate(to)],
    );
    return (rows.first['total'] as int, rows.first['cnt'] as int);
  }

  /// Map "yyyy-MM-dd" (hoặc "yyyy-MM") -> (tổng tiền, số phiếu).
  Future<Map<String, (int, int)>> _grouped(
    String table,
    String dateColumn,
    ReportPeriod period,
    bool byMonth,
  ) async {
    final len = byMonth ? 7 : 10;
    final rows = await _db.rawQuery(
      '''
      SELECT substr($dateColumn, 1, $len) AS k,
             SUM(total_amount) AS total, COUNT(*) AS cnt
      FROM $table
      WHERE status = 'active' AND $dateColumn >= ? AND $dateColumn < ?
      GROUP BY k
    ''',
      [toDbDate(period.start), toDbDate(period.end)],
    );
    return {
      for (final r in rows)
        r['k'] as String: (r['total'] as int, r['cnt'] as int),
    };
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(appDatabaseProvider)),
);
