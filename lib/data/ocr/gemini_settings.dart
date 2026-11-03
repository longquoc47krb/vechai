import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cài đặt Gemini (AI đọc phiếu). Khóa API do người dùng tự nhập trong app,
/// lưu MÃ HÓA trên máy (Android Keystore) - không bao giờ nằm trong mã nguồn.
class GeminiSettings {
  const GeminiSettings({this.apiKey, this.model = defaultModel});

  /// Model có gói miễn phí, đã thử đọc đúng phiếu viết tay mẫu (11/2026).
  /// Đổi được trong Cài đặt nếu Google ngừng model này.
  static const defaultModel = 'gemini-3.5-flash-lite';

  final String? apiKey;
  final String model;

  bool get isConfigured => (apiKey ?? '').trim().isNotEmpty;
}

class GeminiSettingsRepository {
  GeminiSettingsRepository([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyApiKey = 'gemini_api_key';
  static const _keyModel = 'gemini_model';

  Future<GeminiSettings> load() async {
    final model = await _storage.read(key: _keyModel);
    return GeminiSettings(
      apiKey: await _storage.read(key: _keyApiKey),
      model: (model == null || model.trim().isEmpty)
          ? GeminiSettings.defaultModel
          : model.trim(),
    );
  }

  Future<void> save({required String apiKey, required String model}) async {
    await _storage.write(key: _keyApiKey, value: apiKey.trim());
    await _storage.write(key: _keyModel, value: model.trim());
  }
}

final geminiSettingsRepositoryProvider = Provider<GeminiSettingsRepository>(
  (ref) => GeminiSettingsRepository(),
);

final geminiSettingsProvider = FutureProvider<GeminiSettings>(
  (ref) => ref.watch(geminiSettingsRepositoryProvider).load(),
);
