import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../domain/receipt_scan.dart';
import 'gemini_settings.dart';

/// Gửi ảnh phiếu thu mua viết tay lên Google Gemini để đọc thành dữ liệu.
class ReceiptScanner {
  ReceiptScanner(this._client);

  final http.Client _client;

  /// Thời gian chờ tối đa cho MỖI model trước khi chuyển model dự phòng.
  static const _timeout = Duration(seconds: 40);

  /// Đọc ảnh [jpeg]. [productNames] giúp AI dùng đúng tên mặt hàng đã có.
  Future<ScannedReceipt> scan(
    Uint8List jpeg, {
    required GeminiSettings settings,
    required List<String> productNames,
  }) async {
    final text = await _generate(settings, [
      {'text': buildReceiptPrompt(productNames, DateTime.now())},
      {
        'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(jpeg)},
      },
    ], json: true);

    try {
      final decoded = jsonDecode(_stripCodeFence(text));
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return ScannedReceipt.fromJson(decoded);
    } on FormatException {
      throw const AppException(
        'AI trả về dữ liệu không đọc được. Thử chụp lại rõ hơn.',
      );
    }
  }

  /// Gọi thử để kiểm tra khóa API và model (dùng ở màn Cài đặt).
  Future<void> testConnection(GeminiSettings settings) async {
    await _generate(settings, [
      {'text': 'Trả lời đúng 1 chữ: OK'},
    ]);
  }

  Future<String> _generate(
    GeminiSettings settings,
    List<Map<String, Object?>> parts, {
    bool json = false,
  }) async {
    if (!settings.isConfigured) {
      throw const AppException(
        'Chưa có khóa Gemini API. Vào menu ⋮ > Cài đặt để nhập khóa.',
      );
    }
    // Gói miễn phí hay quá tải (503 / treo lâu) -> thử lần lượt model dự phòng.
    final models = {settings.model, ...fallbackModels}.toList();
    http.Response? res;
    for (final model in models) {
      try {
        res = await _post(model, settings.apiKey!.trim(), parts, json: json);
      } on TimeoutException {
        res = null;
        continue;
      }
      if (!_overloaded.contains(res.statusCode)) break;
    }

    if (res == null) {
      throw const AppException(
        'AI phản hồi quá lâu. Máy chủ Google có thể đang quá tải, '
        'thử lại sau ít phút.',
      );
    }
    if (res.statusCode != 200) throw _httpError(res);

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final text = _extractText(body);
    if (text == null || text.trim().isEmpty) {
      throw const AppException(
        'AI không đọc được ảnh này. Thử chụp lại rõ hơn, đủ sáng.',
      );
    }
    return text;
  }

  /// Model dự phòng (đều có gói miễn phí), dùng khi model chính quá tải.
  static const fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.8-flash',
  ];

  /// Mã lỗi "máy chủ bận / tạm lỗi" -> nên thử model khác.
  static const _overloaded = {500, 502, 503, 504};

  Future<http.Response> _post(
    String model,
    String apiKey,
    List<Map<String, Object?>> parts, {
    required bool json,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    try {
      return await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // Gửi khóa qua header, không để trong URL (tránh lộ trong log).
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {'role': 'user', 'parts': parts},
              ],
              'generationConfig': {
                'temperature': 0,
                if (json) 'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(_timeout);
    } on SocketException {
      throw const AppException(
        'Không có kết nối Internet. Đọc phiếu bằng AI cần có mạng.',
      );
    } on http.ClientException {
      throw const AppException(
        'Không có kết nối Internet. Đọc phiếu bằng AI cần có mạng.',
      );
    }
  }

  AppException _httpError(http.Response res) {
    String detail = '';
    try {
      final err = (jsonDecode(res.body) as Map)['error'] as Map?;
      detail = (err?['message'] as String?) ?? '';
    } catch (_) {}

    return switch (res.statusCode) {
      400 when detail.toLowerCase().contains('api key') => const AppException(
        'Khóa Gemini API không hợp lệ. Kiểm tra lại trong Cài đặt.',
      ),
      401 || 403 => const AppException(
        'Khóa Gemini API không hợp lệ hoặc chưa được bật. '
        'Kiểm tra lại trong Cài đặt.',
      ),
      404 => const AppException(
        'Không tìm thấy model AI. Đổi tên model trong Cài đặt '
        '(ví dụ gemini-3.5-flash-lite).',
      ),
      429 => const AppException(
        'Đã hết lượt AI miễn phí tạm thời. Đợi 1 phút rồi thử lại.',
      ),
      503 => const AppException(
        'Máy chủ AI của Google đang quá tải. Thử lại sau ít phút.',
      ),
      _ => AppException(
        'AI báo lỗi (${res.statusCode}). Thử lại sau.'
        '${detail.isEmpty ? '' : '\n$detail'}',
      ),
    };
  }

  static String? _extractText(Object? body) {
    if (body is! Map) return null;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final parts = (candidates.first as Map?)?['content']?['parts'];
    if (parts is! List) return null;
    return parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
  }

  /// Bỏ ```json ... ``` nếu AI lỡ bọc kết quả trong khối code.
  static String _stripCodeFence(String text) {
    final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    return (match?.group(1) ?? text).trim();
  }
}

/// Câu lệnh gửi cho AI. Tách riêng để dễ chỉnh và kiểm thử.
String buildReceiptPrompt(List<String> productNames, DateTime today) {
  final y = today.year;
  return '''
Đây là ảnh phiếu / sổ ghi thu mua ve chai (phế liệu) VIẾT TAY bằng tiếng Việt.
Hãy đọc và trả về DUY NHẤT một JSON đúng dạng:
{
  "date": "YYYY-MM-DD" hoặc null,
  "seller": "tên người bán" hoặc null,
  "items": [
    {
      "name": "tên mặt hàng",
      "quantity": số (khối lượng / số lượng, dùng dấu chấm thập phân),
      "unit": "kg" | "cái" | "bao" | "chai" | "lon" | "thùng" hoặc null,
      "unit_price": số nguyên VNĐ cho 1 đơn vị hoặc null,
      "amount": số nguyên VNĐ thành tiền ghi trên phiếu hoặc null
    }
  ]
}

Quy tắc:
- Mỗi dòng hàng trên phiếu là 1 phần tử trong "items". Bỏ qua dòng tổng cộng.
- Tiền viết tắt phải đổi ra số đầy đủ: "8k" hoặc "8" (khi rõ là nghìn) = 8000,
  "1tr2" = 1200000, "180.000" = 180000. Không kèm dấu chấm, chữ "đ".
- Số lượng "2,5" = 2.5. Nếu ghi kiểu "10 x 8" thì quantity=10, unit_price=8000.
- Ngày thiếu năm thì dùng năm $y. Không đọc được ngày thì để null.
- Nếu tên mặt hàng gần giống một tên trong danh sách sau thì dùng ĐÚNG tên
  trong danh sách: ${productNames.join(', ')}.
- Chữ nào không chắc chắn thì đọc theo khả năng cao nhất; không đọc được
  trường nào thì để null. KHÔNG bịa thêm dòng hàng.
''';
}

final receiptScannerProvider = Provider<ReceiptScanner>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ReceiptScanner(client);
});
