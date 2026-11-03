import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vechai/data/local/app_database.dart';
import 'package:vechai/data/repositories/product_repository.dart';
import 'package:vechai/data/repositories/purchase_repository.dart';
import 'package:vechai/data/repositories/report_repository.dart';
import 'package:vechai/data/repositories/sale_repository.dart';
import 'package:vechai/domain/product.dart';
import 'package:vechai/domain/purchase.dart';
import 'package:vechai/domain/report.dart';
import 'package:vechai/domain/sale.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late PurchaseRepository purchases;
  late SaleRepository sales;
  late ReportRepository reports;
  late Product sat;

  setUp(() async {
    database = await openTestDatabase();
    purchases = PurchaseRepository(database);
    sales = SaleRepository(database);
    reports = ReportRepository(database);
    sat = (await ProductRepository(database).getAll()).firstWhere(
      (p) => p.name == 'Sắt',
    );
  });

  tearDown(() => database.close());

  String id() => const Uuid().v4();

  /// Phiếu thu mua 1 dòng, tổng = [amount].
  Future<String> buy(DateTime date, int amount) async {
    final purchaseId = id();
    await purchases.create(
      purchaseId,
      PurchaseInput(
        purchaseDate: date,
        items: [
          PurchaseItemInput(
            productId: sat.id,
            productName: sat.name,
            unit: sat.unit,
            quantity: 1,
            unitPrice: amount,
          ),
        ],
      ),
    );
    return purchaseId;
  }

  Future<String> sell(DateTime date, int amount) async {
    final saleId = id();
    await sales.create(saleId, SaleInput(saleDate: date, totalAmount: amount));
    return saleId;
  }

  final nov = ReportPeriod.containing(
    ReportPeriodType.month,
    DateTime(2026, 11, 1),
  );

  test('Ví dụ trong yêu cầu: tháng 11 mua 15tr, bán 19,5tr -> lãi 4,5tr', () async {
    await buy(DateTime(2026, 11, 3), 10000000);
    await buy(DateTime(2026, 11, 20), 5000000);
    await sell(DateTime(2026, 11, 10), 12000000);
    await sell(DateTime(2026, 11, 30, 23, 59), 7500000);

    final r = await reports.report(nov);
    expect(r.totals.purchaseTotal, 15000000);
    expect(r.totals.saleTotal, 19500000);
    expect(r.totals.profit, 4500000);
    expect(r.totals.purchaseCount, 2);
    expect(r.totals.saleCount, 2);
  });

  test('Biên kỳ: 31/10 23:59 và 01/12 00:00 không thuộc tháng 11', () async {
    await buy(DateTime(2026, 10, 31, 23, 59), 1000);
    await sell(DateTime(2026, 12, 1), 2000);
    await sell(DateTime(2026, 11, 1), 3000);

    final r = await reports.report(nov);
    expect(r.totals.purchaseTotal, 0);
    expect(r.totals.saleTotal, 3000);
  });

  test('Phiếu hủy không tính; sửa phiếu thì báo cáo tính lại', () async {
    final p = await buy(DateTime(2026, 11, 5), 1000000);
    final s = await sell(DateTime(2026, 11, 5), 3000000);
    await sell(DateTime(2026, 11, 6), 500000);

    await sales.cancel(s);
    await purchases.update(
      p,
      PurchaseInput(
        purchaseDate: DateTime(2026, 11, 5),
        items: [
          PurchaseItemInput(
            productId: sat.id,
            productName: sat.name,
            unit: sat.unit,
            quantity: 2,
            unitPrice: 1000000,
          ),
        ],
      ),
    );

    final r = await reports.report(nov);
    expect(r.totals.purchaseTotal, 2000000);
    expect(r.totals.saleTotal, 500000);
    expect(r.totals.profit, -1500000);
  });

  test('Chia đúng vào từng ngày của tháng', () async {
    await buy(DateTime(2026, 11, 5, 8), 100);
    await buy(DateTime(2026, 11, 5, 17), 200);
    await sell(DateTime(2026, 11, 30), 900);

    final r = await reports.report(nov);
    expect(r.buckets, hasLength(30));
    expect(r.buckets[4].totals.purchaseTotal, 300);
    expect(r.buckets[4].totals.purchaseCount, 2);
    expect(r.buckets[29].totals.saleTotal, 900);
    expect(r.buckets[29].totals.profit, 900);
  });

  test('Báo cáo năm chia theo tháng', () async {
    await buy(DateTime(2026, 1, 31), 100);
    await sell(DateTime(2026, 12, 31, 23), 500);
    await sell(DateTime(2027, 1, 1), 999);

    final year = ReportPeriod.containing(ReportPeriodType.year, DateTime(2026));
    final r = await reports.report(year);
    expect(r.buckets.first.totals.purchaseTotal, 100);
    expect(r.buckets.last.totals.saleTotal, 500);
    expect(r.totals.saleTotal, 500);
  });

  test('Báo cáo tuần (Trang chủ dùng totals theo ngày)', () async {
    await sell(DateTime(2026, 11, 2), 100); // thứ Hai
    await sell(DateTime(2026, 11, 8, 22), 200); // Chủ nhật
    await sell(DateTime(2026, 11, 9), 400); // thứ Hai tuần sau

    final week = ReportPeriod.containing(
      ReportPeriodType.week,
      DateTime(2026, 11, 4),
    );
    expect((await reports.report(week)).totals.saleTotal, 300);

    final day = await reports.totals(DateTime(2026, 11, 8), DateTime(2026, 11, 9));
    expect(day.saleTotal, 200);
    expect(day.saleCount, 1);
  });
}
