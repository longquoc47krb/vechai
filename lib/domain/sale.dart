import 'record_status.dart';

export 'record_status.dart';

/// Phiếu bán hàng: CHỈ ghi tổng tiền bán được, không có chi tiết mặt hàng.
class Sale {
  const Sale({
    required this.id,
    required this.code,
    required this.saleDate,
    required this.totalAmount,
    required this.buyerName,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Mã phiếu dễ đọc, ví dụ BH-20261103-001.
  final String code;
  final DateTime saleDate;
  final int totalAmount;
  final String? buyerName;
  final String? note;
  final RecordStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCancelled => status == RecordStatus.cancelled;

  factory Sale.fromMap(Map<String, Object?> map) => Sale(
    id: map['id'] as String,
    code: map['code'] as String,
    saleDate: DateTime.parse(map['sale_date'] as String),
    totalAmount: map['total_amount'] as int,
    buyerName: map['buyer_name'] as String?,
    note: map['note'] as String?,
    status: RecordStatus.parse(map['status'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

/// Dữ liệu form tạo / sửa phiếu bán.
class SaleInput {
  const SaleInput({
    required this.saleDate,
    required this.totalAmount,
    this.buyerName,
    this.note,
  });

  final DateTime saleDate;
  final int totalAmount;
  final String? buyerName;
  final String? note;

  /// Giới hạn chống gõ nhầm thêm số 0 (100 tỷ).
  static const maxAmount = 100000000000;

  String? validate() {
    if (totalAmount <= 0) return 'Vui lòng nhập tổng tiền bán';
    if (totalAmount > maxAmount) return 'Tổng tiền quá lớn, kiểm tra lại';
    if ((buyerName?.length ?? 0) > 100) return 'Tên người mua quá dài';
    if ((note?.length ?? 0) > 500) return 'Ghi chú quá dài';
    return null;
  }
}
