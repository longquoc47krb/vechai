/// Tổng hợp lượng hàng ĐÃ THU MUA của một mặt hàng (không phải tồn kho
/// thực tế, vì phiếu bán không ghi chi tiết mặt hàng).
class InventoryRow {
  const InventoryRow({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unit,
    required this.totalQuantity,
    required this.totalAmount,
    required this.purchaseCount,
    required this.lastPurchaseDate,
  });

  final String productId;
  final String productName;
  final String category;
  final String unit;
  final double totalQuantity;
  final int totalAmount;

  /// Số phiếu có mặt hàng này.
  final int purchaseCount;
  final DateTime lastPurchaseDate;

  /// Giá thu mua bình quân trên mỗi đơn vị.
  int get averagePrice =>
      totalQuantity == 0 ? 0 : (totalAmount / totalQuantity).round();
}

/// Một lần nhập của mặt hàng (lịch sử nhập hàng).
class ProductPurchaseEntry {
  const ProductPurchaseEntry({
    required this.purchaseId,
    required this.purchaseCode,
    required this.purchaseDate,
    required this.sellerName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.amount,
  });

  final String purchaseId;
  final String purchaseCode;
  final DateTime purchaseDate;
  final String? sellerName;
  final double quantity;
  final String unit;
  final int unitPrice;
  final int amount;
}

/// Khoảng thời gian xem kho.
enum InventoryPeriod {
  all('Tất cả'),
  thisMonth('Tháng này'),
  thisYear('Năm nay');

  const InventoryPeriod(this.label);
  final String label;

  /// [from, to) theo giờ địa phương; null = không giới hạn.
  (DateTime?, DateTime?) range(DateTime now) => switch (this) {
    all => (null, null),
    thisMonth => (
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ),
    thisYear => (DateTime(now.year), DateTime(now.year + 1)),
  };
}
