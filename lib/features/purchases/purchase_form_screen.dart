import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../domain/product.dart';
import '../../domain/purchase.dart';
import '../products/products_providers.dart';
import 'purchase_item_sheet.dart';
import 'purchases_providers.dart';
import 'receipt_scan_flow.dart';

/// Màn tạo phiếu mới ([purchaseId] == null) hoặc sửa phiếu.
class PurchaseFormScreen extends ConsumerWidget {
  const PurchaseFormScreen({super.key, this.purchaseId});

  final String? purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final id = purchaseId;
    final purchaseAsync = id == null
        ? const AsyncValue<Purchase?>.data(null)
        : ref.watch(purchaseDetailProvider(id));

    Widget message(String text) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );

    if (productsAsync.hasError) {
      return message(friendlyError(productsAsync.error!));
    }
    if (purchaseAsync.hasError) {
      return message(friendlyError(purchaseAsync.error!));
    }
    final products = productsAsync.value;
    if (products == null || purchaseAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final purchase = purchaseAsync.value;
    if (id != null && purchase == null) return message('Không tìm thấy phiếu');
    if (purchase != null && purchase.isCancelled) {
      return message('Phiếu đã hủy, không sửa được');
    }

    return _PurchaseForm(purchase: purchase, allProducts: products);
  }
}

class _PurchaseForm extends ConsumerStatefulWidget {
  const _PurchaseForm({required this.purchase, required this.allProducts});

  final Purchase? purchase;
  final List<Product> allProducts;

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  /// Phiếu mới được cấp UUID ngay khi mở form -> lưu lại nhiều lần
  /// vẫn chỉ ra 1 phiếu (xem PurchaseRepository.create).
  late final String _id;
  late DateTime _date;
  late final TextEditingController _seller;
  late final TextEditingController _note;
  late final List<PurchaseItemInput> _items;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.purchase != null;

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    _id = p?.id ?? const Uuid().v4();
    _date = p?.purchaseDate ?? DateTime.now();
    _seller = TextEditingController(text: p?.sellerName ?? '');
    _note = TextEditingController(text: p?.note ?? '');
    _items = [...?p?.items.map((i) => i.toInput())];
    _seller.addListener(_markDirty);
    _note.addListener(_markDirty);
  }

  @override
  void dispose() {
    _seller.dispose();
    _note.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  PurchaseInput get _input => PurchaseInput(
    purchaseDate: _date,
    sellerName: _seller.text,
    note: _note.text,
    items: _items,
  );

  /// Mặt hàng cho phép chọn: đang kinh doanh + mặt hàng đang có trong phiếu
  /// (kể cả đã ngừng, để sửa phiếu cũ không bị mất lựa chọn).
  List<Product> get _selectableProducts {
    final inPurchase = _items.map((i) => i.productId).toSet();
    return widget.allProducts
        .where((p) => p.isActive || inPurchase.contains(p.id))
        .toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      // Giữ nguyên giờ phút, chỉ đổi ngày.
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      _dirty = true;
    });
  }

  Future<void> _addOrEditItem([int? index]) async {
    final result = await showPurchaseItemSheet(
      context,
      products: _selectableProducts,
      initial: index == null ? null : _items[index],
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
      _dirty = true;
    });
  }

  void _removeItem(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
      _dirty = true;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa dòng ${removed.productName}'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => setState(() => _items.insert(index, removed)),
          ),
        ),
      );
  }

  /// Chụp ảnh phiếu viết tay -> AI đọc -> người dùng xem lại -> thêm dòng.
  Future<void> _scanReceipt() async {
    final result = await scanReceipt(
      context,
      ref,
      products: widget.allProducts,
    );
    if (result == null || !mounted) return;
    setState(() {
      _items.addAll(result.items);
      final date = result.date;
      if (date != null) {
        // Giữ giờ phút hiện tại, lấy ngày trên phiếu.
        _date = DateTime(
          date.year,
          date.month,
          date.day,
          _date.hour,
          _date.minute,
        );
      }
      final seller = result.sellerName;
      if (seller != null && _seller.text.trim().isEmpty) _seller.text = seller;
      _dirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${result.items.length} dòng từ ảnh phiếu'),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = _input.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final saved = _isEdit
          ? await repo.update(_id, _input)
          : await repo.create(_id, _input);
      refreshPurchaseData(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu phiếu ${saved.code}')),
      );
      if (_isEdit) {
        context.pop();
      } else {
        // Thay màn form bằng màn chi tiết phiếu vừa tạo.
        context.pushReplacement(Routes.purchaseDetail(saved.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Bỏ thay đổi?',
      message: 'Phiếu chưa được lưu. Thoát sẽ mất các thông tin vừa nhập.',
      confirmLabel: 'Thoát',
      cancelLabel: 'Ở lại',
      destructive: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _input.totalAmount;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit ? 'Sửa ${widget.purchase!.code}' : 'Phiếu thu mua mới',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Ngày thu mua'),
                subtitle: Text(
                  formatDateTime(_date),
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _seller,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Người bán (không bắt buộc)',
                prefixIcon: Icon(Icons.person_outline),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                prefixIcon: Icon(Icons.notes),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Mặt hàng (${_items.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (_items.isNotEmpty)
                  Text(
                    'Chạm để sửa',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (index, item) in _items.indexed) ...[
              _ItemCard(
                item: item,
                onTap: () => _addOrEditItem(index),
                onDelete: () => _removeItem(index),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _addOrEditItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm mặt hàng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saving ? null : _scanReceipt,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Chụp phiếu'),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng tiền thu mua'),
                      Text(
                        formatVnd(total),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving || _items.isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu phiếu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final PurchaseItemInput item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(
          item.productName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatQuantity(item.quantity)} ${item.unit} × '
          '${formatVnd(item.unitPrice)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatVnd(item.amount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'Xóa dòng',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
