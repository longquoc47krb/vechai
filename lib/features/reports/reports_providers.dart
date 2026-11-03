import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/report_repository.dart';
import '../../domain/report.dart';

final reportProvider = FutureProvider.family<ReportData, ReportPeriod>(
  (ref, period) => ref.watch(reportRepositoryProvider).report(period),
);

/// Số liệu hôm nay cho Trang chủ.
final todayTotalsProvider = FutureProvider<ReportTotals>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref
      .watch(reportRepositoryProvider)
      .totals(today, DateTime(now.year, now.month, now.day + 1));
});

/// Gọi sau mọi thay đổi phiếu thu mua / bán để báo cáo tính lại.
void refreshReports(WidgetRef ref) {
  ref.invalidate(reportProvider);
  ref.invalidate(todayTotalsProvider);
}
