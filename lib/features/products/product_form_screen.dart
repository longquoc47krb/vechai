import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/widgets/money_field.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/product.dart';
import 'products_providers.dart';

/// Màn thêm mới ([productId] == null) hoặc sửa mặt hàng.
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) return const _ProductForm(product: null);

    final async = ref.watch(productByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(friendlyError(e))),
      ),
      data: (product) => product == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Không tìm thấy mặt hàng')),
            )
          : _ProductForm(product: product),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.product});

  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _buyPrice;
  late final TextEditingController _sellPrice;
  late String _category;
  late String _unit;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _buyPrice = TextEditingController(
      text: p == null ? '' : formatMoneyInput(p.defaultPurchasePrice),
    );
    _sellPrice = TextEditingController(
      text: p == null ? '' : formatMoneyInput(p.referenceSalePrice),
    );
    _category = p?.category ?? ProductOptions.categories.first;
    _unit = p?.unit ?? ProductOptions.units.first;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // _saving chặn bấm "Lưu" nhiều lần liên tiếp -> không tạo bản ghi trùng.
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final input = ProductInput(
      name: _name.text,
      category: _category,
      unit: _unit,
      defaultPurchasePrice: parseMoney(_buyPrice.text) ?? 0,
      referenceSalePrice: parseMoney(_sellPrice.text) ?? 0,
      isActive: _isActive,
    );

    try {
      final repo = ref.read(productRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.product!.id, input);
        ref.invalidate(productByIdProvider(widget.product!.id));
      } else {
        await repo.create(input);
      }
      ref.invalidate(productsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Đã lưu thay đổi' : 'Đã thêm mặt hàng')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa mặt hàng' : 'Thêm mặt hàng')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              maxLength: ProductInput.maxNameLength,
              decoration: const InputDecoration(
                labelText: 'Tên mặt hàng *',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên mặt hàng'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Nhóm hàng'),
                    items: [
                      for (final c in ProductOptions.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Đơn vị'),
                    items: [
                      for (final u in ProductOptions.units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MoneyField(
              controller: _buyPrice,
              label: 'Giá thu mua mặc định',
              helperText: 'Tự điền khi tạo phiếu thu mua, sửa được từng lần',
            ),
            const SizedBox(height: 16),
            MoneyField(
              controller: _sellPrice,
              label: 'Giá bán tham khảo',
              helperText: 'Chỉ để tham khảo',
            ),
            if (_isEdit) ...[
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  title: const Text('Đang kinh doanh'),
                  subtitle: Text(
                    _isActive
                        ? 'Hiện trong danh sách chọn khi thu mua'
                        : 'Ẩn khi thu mua, lịch sử phiếu cũ vẫn giữ nguyên',
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
