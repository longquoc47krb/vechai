import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/money_field.dart';
import '../../core/widgets/quantity_field.dart';
import '../../domain/product.dart';
import '../../domain/purchase.dart';
import '../products/products_providers.dart';

/// Bảng trượt từ dưới lên để thêm / sửa 1 dòng hàng của phiếu thu mua.
/// Trả về dòng hàng mới, hoặc null nếu người dùng đóng lại.
///
/// [prefill] (khi thêm mới): điền sẵn tên / số lượng / đơn giá, ví dụ từ
/// kết quả AI đọc ảnh phiếu; người dùng chỉ cần chọn đúng mặt hàng.
Future<PurchaseItemInput?> showPurchaseItemSheet(
  BuildContext context, {
  required List<Product> products,
  PurchaseItemInput? initial,
  ItemPrefill? prefill,
}) {
  return showModalBottomSheet<PurchaseItemInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _PurchaseItemSheet(
      products: products,
      initial: initial,
      prefill: prefill,
    ),
  );
}

class ItemPrefill {
  const ItemPrefill({required this.name, this.quantity, this.unitPrice});

  final String name;
  final double? quantity;
  final int? unitPrice;
}

class _PurchaseItemSheet extends StatefulWidget {
  const _PurchaseItemSheet({
    required this.products,
    this.initial,
    this.prefill,
  });

  final List<Product> products;
  final PurchaseItemInput? initial;
  final ItemPrefill? prefill;

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _nameFocus = FocusNode();
  final _quantityFocus = FocusNode();

  /// Mặt hàng đã chọn từ gợi ý. null = đang gõ / chưa chọn.
  Product? _product;

  /// Bản sao danh sách để thêm được mặt hàng vừa tạo ngay trong bảng này.
  late final List<Product> _products = [...widget.products];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _product = _products
          .where((p) => p.id == initial.productId)
          .firstOrNull;
      _name.text = _product?.name ?? '';
      _quantity.text = quantityToInput(initial.quantity);
      _price.text = formatMoneyInput(initial.unitPrice);
    } else if (widget.prefill case final prefill?) {
      _name.text = prefill.name;
      if (prefill.quantity != null) {
        _quantity.text = quantityToInput(prefill.quantity!);
      }
      if (prefill.unitPrice != null) {
        _price.text = formatMoneyInput(prefill.unitPrice!);
      }
    }
    for (final c in [_name, _quantity, _price]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _nameFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _onNameChanged(String text) {
    // Sửa chữ sau khi đã chọn -> bỏ chọn, hiện lại gợi ý.
    if (_product != null && text != _product!.name) {
      setState(() => _product = null);
    }
  }

  void _select(Product p) {
    setState(() {
      _product = p;
      _name.text = p.name;
      // Tự điền giá thu mua mặc định, trừ khi đã có giá đọc từ phiếu.
      if (widget.prefill?.unitPrice == null || _price.text.isEmpty) {
        _price.text = formatMoneyInput(p.defaultPurchasePrice);
      }
    });
    _quantityFocus.requestFocus();
  }

  /// Mở form thêm mặt hàng (điền sẵn chữ đang gõ), tạo xong thì chọn luôn.
  /// Phiếu đang nhập dở không bị mất vì form mở đè lên trên.
  Future<void> _createProduct() async {
    final typed = _name.text.trim();
    final created = await context.push<Product>(
      Routes.productNew,
      extra: typed.isEmpty ? null : typed,
    );
    if (created == null || !mounted) return;
    _products.add(created);
    _select(created);
  }

  void _submit() {
    final p = _product;
    if (!_formKey.currentState!.validate() || p == null) return;
    Navigator.pop(
      context,
      PurchaseItemInput(
        productId: p.id,
        productName: p.name,
        unit: p.unit,
        quantity: parseQuantity(_quantity.text)!,
        unitPrice: parseMoney(_price.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = parseQuantity(_quantity.text) ?? 0;
    final price = parseMoney(_price.text) ?? 0;
    final p = _product;

    return Padding(
      // Đẩy nội dung lên trên bàn phím.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              widget.initial == null ? 'Thêm mặt hàng' : 'Sửa dòng hàng',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Mặt hàng *',
                hintText: 'Gõ tên để tìm, ví dụ: sat, dong...',
                prefixIcon: Icon(
                  p == null ? Icons.search : Icons.check_circle,
                  color: p == null ? null : theme.colorScheme.primary,
                ),
                suffixIcon: _name.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _name.clear();
                          setState(() => _product = null);
                          _nameFocus.requestFocus();
                        },
                      ),
              ),
              onChanged: _onNameChanged,
              validator: (_) =>
                  _product == null ? 'Chọn mặt hàng trong danh sách gợi ý' : null,
            ),
            if (p == null) _Suggestions(
              products: _products,
              query: _name.text,
              onSelect: _select,
              onCreate: _createProduct,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    focusNode: _quantityFocus,
                    autofocus: widget.initial != null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [QuantityInputFormatter()],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Số lượng *',
                      suffixText: p?.unit,
                    ),
                    validator: (v) {
                      final value = parseQuantity(v ?? '');
                      if (value == null || value <= 0) {
                        return 'Nhập số lượng > 0';
                      }
                      if (value > PurchaseItemInput.maxQuantity) {
                        return 'Số lượng quá lớn';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneyField(
                    controller: _price,
                    label: p == null ? 'Đơn giá' : 'Đơn giá / ${p.unit}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Thành tiền', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  formatVnd(calcLineAmount(quantity, price)),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(
                widget.initial == null ? 'Thêm vào phiếu' : 'Cập nhật',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danh sách gợi ý hiện ngay dưới ô "Mặt hàng" khi đang gõ.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.products,
    required this.query,
    required this.onSelect,
    required this.onCreate,
  });

  final List<Product> products;
  final String query;
  final ValueChanged<Product> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typed = query.trim();
    final matches = suggestProducts(products, typed);
    final canCreate = typed.isEmpty || !hasExactProduct(products, typed);

    return Card(
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final p in matches)
            ListTile(
              dense: true,
              title: Text(
                p.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${p.category} • ${formatVnd(p.defaultPurchasePrice)}/${p.unit}',
              ),
              onTap: () => onSelect(p),
            ),
          if (matches.isEmpty)
            ListTile(
              dense: true,
              title: Text(
                'Không tìm thấy "$typed"',
                style: TextStyle(color: scheme.outline),
              ),
            ),
          if (canCreate) ...[
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(Icons.add_circle_outline, color: scheme.primary),
              title: Text(
                typed.isEmpty
                    ? 'Thêm mặt hàng mới'
                    : 'Thêm mặt hàng mới "$typed"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              onTap: onCreate,
            ),
          ],
        ],
      ),
    );
  }
}
