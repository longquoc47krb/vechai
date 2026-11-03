/// Một nhóm phiếu trong cùng 1 ngày (để hiển thị danh sách theo ngày).
class DayGroup<T> {
  DayGroup(this.day);

  final DateTime day;
  final List<T> items = [];

  /// Tổng tiền các phiếu CHƯA HỦY trong ngày (được tính khi nhóm).
  int activeTotal = 0;
}

/// Nhóm [items] (đã sắp xếp mới nhất trước) theo ngày.
List<DayGroup<T>> groupByDay<T>(
  Iterable<T> items, {
  required DateTime Function(T) dateOf,
  required int Function(T) amountOf,
  required bool Function(T) isCancelled,
}) {
  final groups = <DayGroup<T>>[];
  for (final item in items) {
    final d = dateOf(item);
    final day = DateTime(d.year, d.month, d.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(DayGroup<T>(day));
    }
    groups.last.items.add(item);
    if (!isCancelled(item)) groups.last.activeTotal += amountOf(item);
  }
  return groups;
}
