/// Mặt hàng thu mua (Sắt, Đồng, Nhôm...).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.defaultPurchasePrice,
    required this.referenceSalePrice,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String unit;

  /// Giá thu mua mặc định (VNĐ / đơn vị), tự điền khi tạo phiếu thu mua.
  final int defaultPurchasePrice;

  /// Giá bán tham khảo (VNĐ / đơn vị), chỉ để tham khảo.
  final int referenceSalePrice;

  /// false = ngừng kinh doanh: ẩn khỏi danh sách chọn khi thu mua,
  /// nhưng vẫn giữ để lịch sử phiếu cũ hiển thị đúng.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      unit: map['unit'] as String,
      defaultPurchasePrice: map['default_purchase_price'] as int,
      referenceSalePrice: map['reference_sale_price'] as int,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Dữ liệu người dùng nhập ở form thêm / sửa mặt hàng.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.category,
    required this.unit,
    required this.defaultPurchasePrice,
    required this.referenceSalePrice,
    this.isActive = true,
  });

  final String name;
  final String category;
  final String unit;
  final int defaultPurchasePrice;
  final int referenceSalePrice;
  final bool isActive;

  static const maxNameLength = 100;

  /// Trả về thông báo lỗi, hoặc null nếu hợp lệ.
  String? validate() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Vui lòng nhập tên mặt hàng';
    if (trimmed.length > maxNameLength) {
      return 'Tên mặt hàng tối đa $maxNameLength ký tự';
    }
    if (!ProductOptions.categories.contains(category)) {
      return 'Nhóm hàng không hợp lệ';
    }
    if (!ProductOptions.units.contains(unit)) return 'Đơn vị không hợp lệ';
    if (defaultPurchasePrice < 0 || referenceSalePrice < 0) {
      return 'Giá không được âm';
    }
    return null;
  }
}

/// Danh sách lựa chọn cố định cho nhóm hàng và đơn vị tính.
class ProductOptions {
  ProductOptions._();

  static const categories = [
    'Kim loại',
    'Nhựa',
    'Giấy',
    'Thủy tinh',
    'Điện tử',
    'Khác',
  ];

  static const units = ['kg', 'cái', 'bao', 'chai', 'lon', 'thùng'];
}
