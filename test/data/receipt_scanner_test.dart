import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vechai/core/errors.dart';
import 'package:vechai/data/ocr/gemini_settings.dart';
import 'package:vechai/data/ocr/receipt_scanner.dart';

/// Phản hồi giả của Gemini với [text] là nội dung model trả về.
http.Response _gemini(String text) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    }),
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  const settings = GeminiSettings(apiKey: 'AIza-test', model: 'gemini-test');
  final image = Uint8List.fromList([1, 2, 3]);

  test('Gửi đúng endpoint, header khóa, ảnh và yêu cầu JSON', () async {
    late http.Request captured;
    final scanner = ReceiptScanner(
      MockClient((req) async {
        captured = req;
        return _gemini(
          '{"date":"2026-11-02","seller":"Cô Tư","items":'
          '[{"name":"Sắt","quantity":10,"unit":"kg","unit_price":8000}]}',
        );
      }),
    );

    final r = await scanner.scan(
      image,
      settings: settings,
      productNames: ['Sắt', 'Đồng'],
    );

    expect(
      captured.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-test:generateContent',
    );
    expect(captured.headers['x-goog-api-key'], 'AIza-test');
    expect(captured.url.queryParameters, isEmpty, reason: 'không để khóa trong URL');

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final parts = body['contents'][0]['parts'] as List;
    expect(parts[0]['text'], contains('Sắt, Đồng'));
    expect(parts[1]['inlineData']['mimeType'], 'image/jpeg');
    expect(parts[1]['inlineData']['data'], base64Encode(image));
    expect(body['generationConfig']['responseMimeType'], 'application/json');

    expect(r.sellerName, 'Cô Tư');
    expect(r.lines.single.unitPrice, 8000);
  });

  test('Model chính quá tải (503) -> tự chuyển model dự phòng', () async {
    final tried = <String>[];
    final scanner = ReceiptScanner(
      MockClient((req) async {
        tried.add(req.url.pathSegments.last);
        if (tried.length < 3) {
          return http.Response('{"error":{"message":"high demand"}}', 503);
        }
        return _gemini('{"items":[{"name":"Sắt","quantity":1}]}');
      }),
    );
    final r = await scanner.scan(image, settings: settings, productNames: []);
    expect(tried, [
      'gemini-test:generateContent',
      'gemini-3.5-flash-lite:generateContent',
      'gemini-3.6-flash:generateContent',
    ]);
    expect(r.lines.single.name, 'Sắt');
  });

  test('Tất cả model quá tải -> báo thử lại sau', () async {
    final scanner = ReceiptScanner(
      MockClient((_) async => http.Response('{}', 503)),
    );
    await expectLater(
      scanner.scan(image, settings: settings, productNames: []),
      throwsA(
        isA<AppException>().having((e) => e.message, 'message', contains('quá tải')),
      ),
    );
  });

  test('Chấp nhận JSON bị bọc trong ```json', () async {
    final scanner = ReceiptScanner(
      MockClient(
        (_) async => _gemini('```json\n{"items":[{"name":"Nhôm","quantity":2}]}\n```'),
      ),
    );
    final r = await scanner.scan(image, settings: settings, productNames: []);
    expect(r.lines.single.name, 'Nhôm');
  });

  test('Chưa nhập khóa -> báo lỗi, không gọi mạng', () async {
    var called = false;
    final scanner = ReceiptScanner(
      MockClient((_) async {
        called = true;
        return _gemini('{}');
      }),
    );
    await expectLater(
      scanner.scan(image, settings: const GeminiSettings(), productNames: []),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Cài đặt'))),
    );
    expect(called, isFalse);
  });

  group('Lỗi HTTP -> thông báo dễ hiểu', () {
    Future<String> errorFor(int status, [String message = '']) async {
      final scanner = ReceiptScanner(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': message},
            }),
            status,
          ),
        ),
      );
      try {
        await scanner.scan(image, settings: settings, productNames: []);
      } on AppException catch (e) {
        return e.message;
      }
      fail('phải báo lỗi');
    }

    test('429 hết lượt miễn phí', () async {
      expect(await errorFor(429), contains('hết lượt'));
    });
    test('403 / 400 khóa sai', () async {
      expect(await errorFor(403), contains('không hợp lệ'));
      expect(await errorFor(400, 'API key not valid'), contains('không hợp lệ'));
    });
    test('404 model không tồn tại', () async {
      expect(await errorFor(404), contains('model'));
    });
  });

  test('AI trả về chữ không phải JSON -> báo chụp lại', () async {
    final scanner = ReceiptScanner(
      MockClient((_) async => _gemini('Xin lỗi, tôi không đọc được.')),
    );
    await expectLater(
      scanner.scan(image, settings: settings, productNames: []),
      throwsA(isA<AppException>()),
    );
  });

  test('Mất mạng -> báo cần Internet', () async {
    final scanner = ReceiptScanner(
      MockClient((_) async => throw http.ClientException('no network')),
    );
    await expectLater(
      scanner.scan(image, settings: settings, productNames: []),
      throwsA(
        isA<AppException>().having((e) => e.message, 'message', contains('Internet')),
      ),
    );
  });
}
