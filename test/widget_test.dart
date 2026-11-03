import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vechai/app.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    Intl.defaultLocale = 'vi';
  });

  testWidgets('Có 5 tab và chuyển tab được', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeChaiApp()));
    await tester.pumpAndSettle();

    for (final label in [
      'Trang chủ',
      'Thu mua',
      'Bán hàng',
      'Kho hàng',
      'Báo cáo',
    ]) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(NavigationDestination, 'Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Giai đoạn 6'), findsOneWidget);
  });

  testWidgets('Menu mở được màn Mặt hàng', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeChaiApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mặt hàng'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Giai đoạn 2'), findsOneWidget);
    // Màn phụ mở đè lên nên không còn thanh tab.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
