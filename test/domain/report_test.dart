import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vechai/core/utils/formatters.dart';
import 'package:vechai/domain/report.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Tuần: thứ Hai -> Chủ nhật', () {
    ReportPeriod week(DateTime d) =>
        ReportPeriod.containing(ReportPeriodType.week, d);

    test('03/11/2026 (thứ Ba) thuộc tuần 02/11 – 08/11', () {
      final w = week(DateTime(2026, 11, 3, 15));
      expect(w.start, DateTime(2026, 11, 2));
      expect(w.end, DateTime(2026, 11, 9));
      expect(w.lastDay, DateTime(2026, 11, 8));
      expect(w.label, '02/11 – 08/11/2026');
    });

    test('Chủ nhật 23:59 vẫn thuộc tuần đó, thứ Hai sau thì không', () {
      final w = week(DateTime(2026, 11, 8, 23, 59));
      expect(w.start, DateTime(2026, 11, 2));
      expect(w.contains(DateTime(2026, 11, 8, 23, 59)), isTrue);
      expect(w.contains(DateTime(2026, 11, 9)), isFalse);
    });

    test('Tuần vắt qua năm mới', () {
      final w = week(DateTime(2027, 1, 1)); // thứ Sáu
      expect(w.start, DateTime(2026, 12, 28));
      expect(w.end, DateTime(2027, 1, 4));
      expect(w.next.start, DateTime(2027, 1, 4));
      expect(w.previous.start, DateTime(2026, 12, 21));
    });

    test('7 mốc T2..CN', () {
      final b = week(DateTime(2026, 11, 3)).buckets;
      expect(b.map((e) => e.label), ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
      expect(b.last.start, DateTime(2026, 11, 8));
    });
  });

  group('Tháng', () {
    ReportPeriod month(int y, int m) =>
        ReportPeriod.containing(ReportPeriodType.month, DateTime(y, m, 15));

    test('từ ngày 1 đến hết ngày cuối tháng', () {
      final m = month(2026, 11);
      expect(m.start, DateTime(2026, 11));
      expect(m.end, DateTime(2026, 12));
      expect(m.label, 'Tháng 11/2026');
      expect(m.buckets, hasLength(30));
    });

    test('số ngày đúng: tháng 2 thường / nhuận, tháng 12', () {
      expect(month(2026, 2).buckets, hasLength(28));
      expect(month(2028, 2).buckets, hasLength(29));
      expect(month(2026, 12).buckets, hasLength(31));
      expect(month(2026, 12).next.start, DateTime(2027, 1));
      expect(month(2026, 1).previous.start, DateTime(2025, 12));
    });
  });

  test('Năm: 01/01 -> 31/12, 12 mốc tháng', () {
    final y = ReportPeriod.containing(ReportPeriodType.year, DateTime(2026, 7));
    expect(y.start, DateTime(2026));
    expect(y.lastDay, DateTime(2026, 12, 31));
    expect(y.label, 'Năm 2026');
    expect(y.buckets.map((b) => b.label).first, 'T1');
    expect(y.buckets, hasLength(12));
  });

  test('Kỳ dùng được làm key (so sánh bằng)', () {
    final a = ReportPeriod.containing(ReportPeriodType.week, DateTime(2026, 11, 3));
    final b = ReportPeriod.containing(ReportPeriodType.week, DateTime(2026, 11, 5));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('Lợi nhuận = bán − thu mua', () {
    const t = ReportTotals(purchaseTotal: 15000000, saleTotal: 19500000);
    expect(t.profit, 4500000);
    const loss = ReportTotals(purchaseTotal: 2000000, saleTotal: 500000);
    expect(loss.profit, -1500000);
  });

  test('formatCompactVnd', () {
    expect(formatCompactVnd(0), '0');
    expect(formatCompactVnd(850000), '850k');
    expect(formatCompactVnd(1200000), '1,2tr');
    expect(formatCompactVnd(-1500000), '-1,5tr');
    expect(formatCompactVnd(2500000000), '2,5 tỷ');
  });
}
