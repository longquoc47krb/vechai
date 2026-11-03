import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors.dart';
import '../../core/router/app_router.dart';
import '../../data/ocr/gemini_settings.dart';
import '../../data/ocr/receipt_scanner.dart';
import '../../domain/product.dart';
import '../../domain/receipt_scan.dart';
import 'receipt_review_screen.dart';

/// Toàn bộ quy trình: chọn nguồn ảnh -> chụp/chọn -> AI đọc -> màn xem lại.
/// Trả về null nếu người dùng hủy ở bất kỳ bước nào hoặc có lỗi (đã báo).
Future<ReceiptReviewResult?> scanReceipt(
  BuildContext context,
  WidgetRef ref, {
  required List<Product> products,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final settings = await ref.read(geminiSettingsProvider.future);
  if (!context.mounted) return null;

  if (!settings.isConfigured) {
    final goSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chưa cài đặt AI đọc phiếu'),
        content: const Text(
          'Cần nhập khóa Gemini API (miễn phí) trong Cài đặt trước khi '
          'dùng tính năng chụp phiếu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
    if (goSettings == true && context.mounted) {
      await context.push(Routes.settings);
    }
    return null;
  }

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh phiếu'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;

  // Thu nhỏ ảnh: đủ nét để đọc chữ, gửi nhanh, ít tốn lượt miễn phí.
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Không mở được máy ảnh / thư viện ảnh.\n$e')),
    );
    return null;
  }
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;

  final activeProducts = products.where((p) => p.isActive).toList();
  final scan = ref
      .read(receiptScannerProvider)
      .scan(
        bytes,
        settings: settings,
        productNames: [for (final p in activeProducts) p.name],
      );

  // Hộp thoại chờ trả về ScannedReceipt nếu thành công, hoặc đối tượng lỗi.
  final outcome = await showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ScanningDialog(scan: scan),
  );
  if (!context.mounted || outcome == null) return null;

  if (outcome is! ScannedReceipt) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyError(outcome)),
        duration: const Duration(seconds: 6),
      ),
    );
    return null;
  }
  if (outcome.lines.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Không tìm thấy dòng hàng nào trong ảnh. Thử chụp gần và rõ hơn.',
        ),
      ),
    );
    return null;
  }

  return Navigator.of(context).push<ReceiptReviewResult>(
    MaterialPageRoute(
      builder: (_) => ReceiptReviewScreen(
        image: bytes,
        receipt: outcome,
        products: products,
      ),
    ),
  );
}

class _ScanningDialog extends StatefulWidget {
  const _ScanningDialog({required this.scan});

  final Future<ScannedReceipt> scan;

  @override
  State<_ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<_ScanningDialog> {
  @override
  void initState() {
    super.initState();
    widget.scan.then(
      (value) {
        if (mounted) Navigator.pop(context, value);
      },
      onError: (Object e) {
        if (mounted) Navigator.pop(context, e);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('AI đang đọc phiếu...\nMất khoảng 5–20 giây.')),
          ],
        ),
      ),
    );
  }
}
