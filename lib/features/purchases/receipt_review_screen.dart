import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/product.dart';
import '../../domain/purchase.dart';
import '../../domain/receipt_scan.dart';
import 'purchase_item_sheet.dart';

/// Kết quả người dùng xác nhận sau khi xem lại ảnh đã quét.
class ReceiptReviewResult {
  const ReceiptReviewResult({this.date, this.sellerName, required this.items});

  final DateTime? date;
  final String? sellerName;
  final List<PurchaseItemInput> items;
}

/// Màn xem lại kết quả AI đọc phiếu: ghép đúng mặt hàng, sửa số liệu,
/// bỏ dòng sai, rồi mới thêm vào phiếu. Không có gì được lưu ở đây.
class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.image,
    required this.receipt,
    required this.products,
  });

  final Uint8List image;
  final ScannedReceipt receipt;
  final List<Product> products;

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late final List<ReceiptDraftLine> _lines = [
    for (final l in widget.receipt.lines)
      ReceiptDraftLine.fromScan(l, widget.products),
  ];
  late bool _useDate = widget.receipt.date != null;
  late bool _useSeller = widget.receipt.sellerName != null;

  /// Danh sách mặt hàng, có thêm mặt hàng mới tạo trong lúc xem lại.
  late final List<Product> _products = [...widget.products];

  Iterable<ReceiptDraftLine> get _included => _lines.where((l) => l.included);

  bool get _canApply =>
      _included.isNotEmpty && _included.every((l) => l.isReady);

  Future<void> _edit(ReceiptDraftLine line) async {
    final scanned = line.scanned;
    final result = await showPurchaseItemSheet(
      context,
      products: _products.where((p) => p.isActive).toList(),
      initial: line.item,
      prefill: line.item == null
          ? ItemPrefill(
              name: scanned.name,
              quantity: scanned.quantity,
              unitPrice: scanned.unitPrice,
            )
          : null,
    );
    if (result == null) return;
    setState(() {
      line.item = result;
      line.included = true;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      ReceiptReviewResult(
        date: _useDate ? widget.receipt.date : null,
        sellerName: _useSeller ? widget.receipt.sellerName : null,
        items: [for (final l in _included) l.item!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.receipt;
    final missing = _included.where((l) => !l.isReady).length;
    final total = _included
        .where((l) => l.isReady)
        .fold(0, (s, l) => s + l.item!.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra kết quả đọc phiếu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ảnh gốc để đối chiếu; chạm để xem to.
          GestureDetector(
            onTap: () => _showImage(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.image,
                height: 160,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm vào ảnh để xem to và đối chiếu',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              title: Text(
                'AI có thể đọc sai chữ viết tay',
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
              subtitle: Text(
                'Kiểm tra từng dòng với ảnh trước khi thêm vào phiếu.',
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ),
          if (r.date != null)
            CheckboxListTile(
              value: _useDate,
              onChanged: (v) => setState(() => _useDate = v!),
              title: Text('Dùng ngày trên phiếu: ${formatDate(r.date!)}'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          if (r.sellerName != null)
            CheckboxListTile(
              value: _useSeller,
              onChanged: (v) => setState(() => _useSeller = v!),
              title: Text('Người bán: ${r.sellerName}'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          Text(
            'Đọc được ${_lines.length} dòng hàng',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final line in _lines) ...[
            _LineCard(
              line: line,
              onTap: () => _edit(line),
              onToggle: (v) => setState(() => line.included = v),
            ),
            const SizedBox(height: 8),
          ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Còn $missing dòng chưa chọn mặt hàng – chạm vào dòng để '
                    'chọn, hoặc bỏ đánh dấu để bỏ qua.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton.icon(
                onPressed: _canApply ? _apply : null,
                icon: const Icon(Icons.playlist_add_check),
                label: Text(
                  'Thêm ${_included.length} dòng vào phiếu • ${formatVnd(total)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.memory(widget.image)),
            ),
            SafeArea(
              child: IconButton.filled(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.onTap,
    required this.onToggle,
  });

  final ReceiptDraftLine line;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = line.scanned;
    final item = line.item;
    final muted = line.included ? null : scheme.outline;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: line.included,
                onChanged: (v) => onToggle(v!),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phiếu ghi: "${s.name}"'
                      '${s.quantity != null ? ' • ${formatQuantity(s.quantity!)}${s.unit != null ? ' ${s.unit}' : ''}' : ''}'
                      '${s.unitPrice != null ? ' × ${formatVnd(s.unitPrice!)}' : ''}',
                      style: TextStyle(color: scheme.outline),
                    ),
                    const SizedBox(height: 4),
                    if (item != null) ...[
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      Text(
                        '${formatQuantity(item.quantity)} ${item.unit} × '
                        '${formatVnd(item.unitPrice)} = ${formatVnd(item.amount)}',
                        style: TextStyle(color: muted),
                      ),
                    ] else
                      Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: scheme.error),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s.quantity == null
                                  ? 'Chưa đọc được số lượng – chạm để nhập'
                                  : 'Chưa khớp mặt hàng – chạm để chọn',
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (s.amountMismatch)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠ Phiếu ghi thành tiền ${formatVnd(s.amount!)}, '
                          'khác số lượng × đơn giá. Kiểm tra lại.',
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
