/// Trạng thái phiếu (dùng chung cho thu mua, bán, chi phí).
/// Phiếu không bao giờ bị xóa, chỉ chuyển sang [cancelled].
enum RecordStatus {
  active,
  cancelled;

  static RecordStatus parse(String value) =>
      value == 'cancelled' ? cancelled : active;
}

/// Thành tiền = Số lượng × Đơn giá, làm tròn tới đồng.
int calcLineAmount(double quantity, int unitPrice) =>
    (quantity * unitPrice).round();

/// Một dòng hàng trong phiếu thu mua đã lưu.
class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  final String id;
  final String productId;

  /// Tên / đơn vị tại thời điểm thu mua (đổi tên mặt hàng sau này
  /// không làm sai phiếu cũ).
  final String productName;
  final String unit;
  final double quantity;
  final int unitPrice;
  final int amount;

  factory PurchaseItem.fromMap(Map<String, Object?> map) => PurchaseItem(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    productName: map['product_name'] as String,
    unit: map['unit'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unitPrice: map['unit_price'] as int,
    amount: map['amount'] as int,
  );

  PurchaseItemInput toInput() => PurchaseItemInput(
    productId: productId,
    productName: productName,
    unit: unit,
    quantity: quantity,
    unitPrice: unitPrice,
  );
}

/// Phiếu thu mua đã lưu.
class Purchase {
  const Purchase({
    required this.id,
    required this.code,
    required this.purchaseDate,
    required this.sellerName,
    required this.note,
    required this.totalAmount,
    required this.status,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;

  /// Mã phiếu dễ đọc, ví dụ TM-20261103-001.
  final String code;
  final DateTime purchaseDate;
  final String? sellerName;
  final String? note;
  final int totalAmount;
  final RecordStatus status;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Chỉ có dữ liệu khi lấy chi tiết 1 phiếu.
  final List<PurchaseItem> items;

  bool get isCancelled => status == RecordStatus.cancelled;

  factory Purchase.fromMap(
    Map<String, Object?> map, {
    List<PurchaseItem> items = const [],
  }) => Purchase(
    id: map['id'] as String,
    code: map['code'] as String,
    purchaseDate: DateTime.parse(map['purchase_date'] as String),
    sellerName: map['seller_name'] as String?,
    note: map['note'] as String?,
    totalAmount: map['total_amount'] as int,
    status: RecordStatus.parse(map['status'] as String),
    itemCount: (map['item_count'] as int?) ?? items.length,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    items: items,
  );
}

/// Một dòng hàng người dùng đang nhập (chưa lưu).
class PurchaseItemInput {
  const PurchaseItemInput({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final int unitPrice;

  int get amount => calcLineAmount(quantity, unitPrice);

  static const maxQuantity = 1000000.0;

  String? validate() {
    if (quantity <= 0) return '$productName: số lượng phải lớn hơn 0';
    if (quantity > maxQuantity) return '$productName: số lượng quá lớn';
    if (unitPrice < 0) return '$productName: đơn giá không được âm';
    return null;
  }
}

/// Dữ liệu form tạo / sửa phiếu thu mua.
class PurchaseInput {
  const PurchaseInput({
    required this.purchaseDate,
    required this.items,
    this.sellerName,
    this.note,
  });

  final DateTime purchaseDate;
  final String? sellerName;
  final String? note;
  final List<PurchaseItemInput> items;

  /// Tổng tiền thu mua = tổng thành tiền các dòng.
  int get totalAmount => items.fold(0, (sum, i) => sum + i.amount);

  String? validate() {
    if (items.isEmpty) return 'Phiếu phải có ít nhất 1 mặt hàng';
    for (final item in items) {
      final error = item.validate();
      if (error != null) return error;
    }
    if ((sellerName?.length ?? 0) > 100) return 'Tên người bán quá dài';
    if ((note?.length ?? 0) > 500) return 'Ghi chú quá dài';
    return null;
  }
}
