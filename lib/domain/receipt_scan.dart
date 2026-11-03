import '../core/utils/text_utils.dart';
import 'product.dart';
import 'purchase.dart';

/// 1 dòng hàng AI đọc được từ ảnh phiếu viết tay. Mọi trường đều có thể
/// thiếu hoặc sai -> người dùng luôn phải xem lại trước khi thêm vào phiếu.
class ScannedLine {
  const ScannedLine({
    required this.name,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.amount,
  });

  final String name;
  final double? quantity;
  final String? unit;

  /// Đơn giá VNĐ / đơn vị.
  final int? unitPrice;

  /// Thành tiền ghi trên phiếu (để đối chiếu với số lượng × đơn giá).
  final int? amount;

  /// Thành tiền app tự tính, null nếu thiếu số lượng / đơn giá.
  int? get computedAmount => quantity == null || unitPrice == null
      ? null
      : calcLineAmount(quantity!, unitPrice!);

  /// true nếu thành tiền ghi trên phiếu khác số app tự tính (lệch > 1%).
  bool get amountMismatch {
    final a = amount;
    final c = computedAmount;
    if (a == null || c == null || a == 0) return false;
    return (a - c).abs() > a * 0.01;
  }

  factory ScannedLine.fromJson(Map<String, Object?> json) => ScannedLine(
    name: (json['name'] as String? ?? '').trim(),
    quantity: parseLooseQuantity(json['quantity']),
    unit: (json['unit'] as String?)?.trim(),
    unitPrice: parseLooseMoney(json['unit_price']),
    amount: parseLooseMoney(json['amount']),
  );
}

/// Toàn bộ kết quả đọc 1 ảnh phiếu.
class ScannedReceipt {
  const ScannedReceipt({this.date, this.sellerName, this.lines = const []});

  final DateTime? date;
  final String? sellerName;
  final List<ScannedLine> lines;

  /// Đọc JSON AI trả về; bỏ qua trường sai định dạng thay vì báo lỗi cả phiếu.
  factory ScannedReceipt.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    return ScannedReceipt(
      date: _parseDate(json['date']),
      sellerName: blankToNull(json['seller'] as String?),
      lines: [
        if (items is List)
          for (final item in items)
            if (item is Map<String, Object?>) ScannedLine.fromJson(item),
      ].where((l) => l.name.isNotEmpty).toList(),
    );
  }

  /// Chỉ nhận ngày hợp lệ, không ở tương lai và không quá cũ (từ 2020).
  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final d = DateTime.tryParse(value.trim());
    if (d == null) return null;
    final now = DateTime.now();
    if (d.isAfter(DateTime(now.year, now.month, now.day + 1))) return null;
    if (d.isBefore(DateTime(2020))) return null;
    return DateTime(d.year, d.month, d.day);
  }
}

/// Số lượng: chấp nhận 2.5, "2,5", "2.5 kg".
double? parseLooseQuantity(Object? value) {
  if (value is num) return value > 0 ? value.toDouble() : null;
  if (value is! String) return null;
  final match = RegExp(r'\d+([.,]\d+)?').firstMatch(value);
  final q = double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '');
  return (q != null && q > 0) ? q : null;
}

/// Tiền: chấp nhận 8000, "8.000", "8,000đ", "8k" (= 8.000), "1tr2" (= 1.200.000).
int? parseLooseMoney(Object? value) {
  if (value is num) return value >= 0 ? value.round() : null;
  if (value is! String) return null;
  final s = normalizeForSearch(value).replaceAll(' ', '');
  final tr = RegExp(r'^(\d+)(?:tr|trieu)(\d*)$').firstMatch(s);
  if (tr != null) {
    final frac = tr.group(2)!;
    return int.parse(tr.group(1)!) * 1000000 +
        (frac.isEmpty ? 0 : (double.parse('0.$frac') * 1000000).round());
  }
  final k = RegExp(r'^(\d+(?:[.,]\d+)?)k$').firstMatch(s);
  if (k != null) {
    return (double.parse(k.group(1)!.replaceAll(',', '.')) * 1000).round();
  }
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

/// Tìm mặt hàng khớp với tên đọc được:
/// 1. trùng tên (bỏ dấu, hoa thường)
/// 2. tên mặt hàng nằm trong tên đọc được ("sắt vụn loại 1" -> "Sắt"),
///    ưu tiên tên dài nhất ("Sắt vụn" thắng "Sắt")
/// 3. tên đọc được nằm trong tên mặt hàng ("carton" -> "Giấy carton")
/// Không khớp -> null, người dùng tự chọn.
Product? matchProduct(List<Product> products, String scannedName) {
  final target = normalizeForSearch(scannedName);
  if (target.isEmpty) return null;

  for (final p in products) {
    if (normalizeForSearch(p.name) == target) return p;
  }

  Product? best;
  var bestLength = 0;
  for (final p in products) {
    final name = normalizeForSearch(p.name);
    if (RegExp('(^| )${RegExp.escape(name)}( |\$)').hasMatch(target) &&
        name.length > bestLength) {
      best = p;
      bestLength = name.length;
    }
  }
  if (best != null) return best;

  final candidates = products
      .where((p) => normalizeForSearch(p.name).contains(target))
      .toList();
  return candidates.length == 1 ? candidates.single : null;
}

/// Dòng đang được xem lại trên màn kiểm tra.
class ReceiptDraftLine {
  ReceiptDraftLine({required this.scanned, this.item, this.included = true});

  final ScannedLine scanned;

  /// Dòng hàng đã ghép với mặt hàng thật; null = chưa ghép được.
  PurchaseItemInput? item;
  bool included;

  bool get isReady => item != null;

  /// Tạo dòng nháp: tự ghép mặt hàng nếu được; đơn giá thiếu thì lấy giá
  /// thu mua mặc định của mặt hàng.
  factory ReceiptDraftLine.fromScan(ScannedLine line, List<Product> products) {
    final product = matchProduct(products, line.name);
    final quantity = line.quantity;
    if (product == null || quantity == null) {
      return ReceiptDraftLine(scanned: line);
    }
    return ReceiptDraftLine(
      scanned: line,
      item: PurchaseItemInput(
        productId: product.id,
        productName: product.name,
        unit: product.unit,
        quantity: quantity,
        unitPrice: line.unitPrice ?? product.defaultPurchasePrice,
      ),
    );
  }
}
