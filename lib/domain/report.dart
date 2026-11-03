import 'package:intl/intl.dart';

enum ReportPeriodType {
  week('Tuần'),
  month('Tháng'),
  year('Năm');

  const ReportPeriodType(this.label);
  final String label;
}

/// Một kỳ báo cáo [start, end) theo giờ địa phương.
/// - Tuần: thứ Hai 00:00 -> thứ Hai tuần sau 00:00 (tức hết Chủ nhật).
/// - Tháng: ngày 1 -> ngày 1 tháng sau.
/// - Năm: 01/01 -> 01/01 năm sau.
class ReportPeriod {
  const ReportPeriod._(this.type, this.start);

  final ReportPeriodType type;
  final DateTime start;

  /// Kỳ chứa ngày [date].
  factory ReportPeriod.containing(ReportPeriodType type, DateTime date) {
    return switch (type) {
      // DateTime(y, m, d - n) tự xử lý lùi qua tháng / năm.
      ReportPeriodType.week => ReportPeriod._(
        type,
        DateTime(date.year, date.month, date.day - (date.weekday - 1)),
      ),
      ReportPeriodType.month => ReportPeriod._(
        type,
        DateTime(date.year, date.month),
      ),
      ReportPeriodType.year => ReportPeriod._(type, DateTime(date.year)),
    };
  }

  /// Ngày đầu tiên của kỳ kế tiếp (không thuộc kỳ này).
  DateTime get end => switch (type) {
    ReportPeriodType.week => DateTime(start.year, start.month, start.day + 7),
    ReportPeriodType.month => DateTime(start.year, start.month + 1),
    ReportPeriodType.year => DateTime(start.year + 1),
  };

  /// Ngày cuối cùng của kỳ (để hiển thị).
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  ReportPeriod get previous => switch (type) {
    ReportPeriodType.week => ReportPeriod._(
      type,
      DateTime(start.year, start.month, start.day - 7),
    ),
    ReportPeriodType.month => ReportPeriod._(
      type,
      DateTime(start.year, start.month - 1),
    ),
    ReportPeriodType.year => ReportPeriod._(type, DateTime(start.year - 1)),
  };

  ReportPeriod get next => ReportPeriod._(type, end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// "03/11 – 09/11/2026", "Tháng 11/2026", "Năm 2026".
  String get label => switch (type) {
    ReportPeriodType.week =>
      '${DateFormat('dd/MM').format(start)} – '
          '${DateFormat('dd/MM/yyyy').format(lastDay)}',
    ReportPeriodType.month => 'Tháng ${DateFormat('MM/yyyy').format(start)}',
    ReportPeriodType.year => 'Năm ${start.year}',
  };

  /// Các mốc nhỏ để vẽ biểu đồ: tuần -> 7 ngày, tháng -> từng ngày,
  /// năm -> 12 tháng.
  List<ReportBucketRange> get buckets {
    if (type == ReportPeriodType.year) {
      return [
        for (var m = 1; m <= 12; m++)
          ReportBucketRange(
            DateTime(start.year, m),
            DateTime(start.year, m + 1),
            'T$m',
          ),
      ];
    }
    var days = 0;
    while (DateTime(start.year, start.month, start.day + days).isBefore(end)) {
      days++;
    }
    return [
      for (var i = 0; i < days; i++)
        ReportBucketRange(
          DateTime(start.year, start.month, start.day + i),
          DateTime(start.year, start.month, start.day + i + 1),
          type == ReportPeriodType.week
              ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]
              : '${i + 1}',
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod && other.type == type && other.start == start;

  @override
  int get hashCode => Object.hash(type, start);

  @override
  String toString() => 'ReportPeriod($type, $label)';
}

class ReportBucketRange {
  const ReportBucketRange(this.start, this.end, this.label);

  final DateTime start;
  final DateTime end;

  /// Nhãn ngắn trên trục: "T2", "15", "T11".
  final String label;
}

/// Tổng hợp tiền trong 1 khoảng thời gian (chỉ phiếu chưa hủy).
class ReportTotals {
  const ReportTotals({
    required this.purchaseTotal,
    required this.saleTotal,
    this.purchaseCount = 0,
    this.saleCount = 0,
  });

  static const zero = ReportTotals(purchaseTotal: 0, saleTotal: 0);

  final int purchaseTotal;
  final int saleTotal;
  final int purchaseCount;
  final int saleCount;

  /// Lợi nhuận = Tổng tiền bán − Tổng tiền thu mua (chênh lệch dòng tiền
  /// trong kỳ, KHÔNG phải lợi nhuận kế toán theo giá vốn).
  int get profit => saleTotal - purchaseTotal;
}

class ReportBucket {
  const ReportBucket(this.range, this.totals);

  final ReportBucketRange range;
  final ReportTotals totals;
}

class ReportData {
  const ReportData({required this.totals, required this.buckets});

  final ReportTotals totals;
  final List<ReportBucket> buckets;
}
