import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/money_field.dart';
import '../../core/widgets/quantity_field.dart';
import '../../domain/product.dart';
import '../../domain/purchase.dart';

/// Bảng trượt từ dưới lên để thêm / sửa 1 dòng hàng của phiếu thu mua.
/// Trả về dòng hàng mới, hoặc null nếu người dùng đóng lại.
Future<PurchaseItemInput?> showPurchaseItemSheet(
  BuildContext context, {
  required List<Product> products,
  PurchaseItemInput? initial,
}) {
  return showModalBottomSheet<PurchaseItemInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _PurchaseItemSheet(
      products: products,
      initial: initial,
    ),
  );
}

class _PurchaseItemSheet extends StatefulWidget {
  const _PurchaseItemSheet({required this.products, this.initial});

  final List<Product> products;
  final PurchaseItemInput? initial;

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _quantityFocus = FocusNode();
  String _search = '';
  Product? _product;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _product = widget.products
          .where((p) => p.id == initial.productId)
          .firstOrNull;
      _quantity.text = quantityToInput(initial.quantity);
      _price.text = formatMoneyInput(initial.unitPrice);
    }
    _quantity.addListener(_refresh);
    _price.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _select(Product p) {
    setState(() {
      _product = p;
      // Tự điền giá thu mua mặc định, người dùng sửa được.
      _price.text = formatMoneyInput(p.defaultPurchasePrice);
    });
    _quantityFocus.requestFocus();
  }

  void _submit() {
    final p = _product;
    if (p == null || !_formKey.currentState!.validate()) return;
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
    final q = normalizeForSearch(_search);
    final visible = widget.products
        .where((p) => q.isEmpty || normalizeForSearch(p.name).contains(q))
        .toList();
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
            if (widget.products.length > 8) ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm mặt hàng',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final product in visible)
                  ChoiceChip(
                    label: Text(product.name),
                    labelStyle: const TextStyle(fontSize: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    selected: product.id == p?.id,
                    onSelected: (_) => _select(product),
                  ),
              ],
            ),
            if (widget.products.isEmpty)
              const Text('Chưa có mặt hàng nào. Hãy thêm ở menu Mặt hàng.'),
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
              onPressed: p == null ? null : _submit,
              child: Text(
                p == null
                    ? 'Chọn mặt hàng'
                    : widget.initial == null
                    ? 'Thêm vào phiếu'
                    : 'Cập nhật',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
