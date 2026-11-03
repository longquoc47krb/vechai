import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../data/ocr/gemini_settings.dart';
import '../../data/ocr/receipt_scanner.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(geminiSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (settings) => _SettingsBody(initial: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.initial});

  final GeminiSettings initial;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late final _apiKey = TextEditingController(text: widget.initial.apiKey);
  late final _model = TextEditingController(text: widget.initial.model);
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  GeminiSettings get _current => GeminiSettings(
    apiKey: _apiKey.text.trim(),
    model: _model.text.trim().isEmpty
        ? GeminiSettings.defaultModel
        : _model.text.trim(),
  );

  Future<void> _save({bool test = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final settings = _current;
      if (test) {
        await ref.read(receiptScannerProvider).testConnection(settings);
      }
      await ref
          .read(geminiSettingsRepositoryProvider)
          .save(apiKey: settings.apiKey ?? '', model: settings.model);
      ref.invalidate(geminiSettingsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            test ? 'Kết nối AI thành công, đã lưu cài đặt' : 'Đã lưu cài đặt',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('AI đọc phiếu viết tay', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onSecondaryContainer),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cách lấy khóa Gemini API miễn phí',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Mở aistudio.google.com bằng trình duyệt, đăng nhập '
                    'tài khoản Google.\n'
                    '2. Chọn "Get API key" > "Create API key".\n'
                    '3. Sao chép khóa (thường bắt đầu bằng "AIza..." hoặc '
                    '"AQ.") và dán vào ô bên dưới.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lưu ý: ở gói miễn phí, Google có thể dùng ảnh gửi lên để '
                    'cải thiện AI của họ. Không chụp giấy tờ nhạy cảm.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiKey,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Khóa Gemini API',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Hiện khóa' : 'Ẩn khóa',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            helperText: 'Lưu mã hóa trên máy này, không gửi đi đâu khác '
                'ngoài Google.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _model,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Model AI',
            prefixIcon: Icon(Icons.memory),
            helperText: 'Mặc định ${GeminiSettings.defaultModel}. Chỉ đổi khi '
                'Google báo ngừng model này.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(),
                child: const Text('Lưu'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _save(test: true),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kiểm tra & lưu'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Đồng bộ Google Sheets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Sẽ có ở Giai đoạn 7'),
          ),
        ),
      ],
    );
  }
}
