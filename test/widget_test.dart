import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vechai/app.dart';
import 'package:vechai/data/local/app_database.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase database;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    Intl.defaultLocale = 'vi';
  });

  setUp(() async => database = await openTestDatabase());
  tearDown(() => database.close());

  Widget app() => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
    child: const VeChaiApp(),
  );

  Future<void> openProducts(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mặt hàng'));
    await tester.pumpAndSettle();
  }

  testWidgets('Có 5 tab và chuyển tab được', (tester) async {
    await tester.pumpWidget(app());
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

    await tester.tap(find.widgetWithText(NavigationDestination, 'Kho hàng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ĐÃ THU MUA'), findsOneWidget);
  });

  testWidgets('Danh sách mặt hàng mẫu + tìm kiếm không dấu', (tester) async {
    await openProducts(tester);

    // Màn phụ mở đè lên nên không còn thanh tab.
    expect(find.byType(NavigationBar), findsNothing);
    // Sắp xếp A-Z theo tiếng Việt: Carton, Chai lọ, Đồng, Giấy...
    expect(find.text('Carton'), findsOneWidget);
    expect(find.text('Đồng'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sat');
    await tester.pumpAndSettle();
    expect(find.text('Sắt'), findsOneWidget);
    expect(find.text('Carton'), findsNothing);
  });

  testWidgets('Thêm mặt hàng mới qua form', (tester) async {
    await openProducts(tester);

    await tester.tap(find.text('Thêm mặt hàng'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên mặt hàng *'),
      'Dây điện',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giá thu mua mặc định'),
      '15000',
    );
    expect(find.text('15.000'), findsOneWidget);

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Đã thêm mặt hàng'), findsOneWidget);
    expect(find.text('Dây điện'), findsOneWidget);
  });

  testWidgets('Tạo phiếu thu mua -> xem chi tiết -> kho cập nhật', (
    tester,
  ) async {
    // Màn hình cỡ điện thoại (400x800) để bottom sheet hiển thị đủ.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Thu mua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có phiếu thu mua'), findsOneWidget);

    await tester.tap(find.text('Tạo phiếu thu mua'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Người bán (không bắt buộc)'),
      'Chú Ba',
    );

    // Thêm dòng: Sắt 10 kg, giá mặc định 8.000đ tự điền.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm mặt hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sắt'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số lượng *'),
      '10,5',
    );
    await tester.pumpAndSettle();
    expect(find.text('84.000đ'), findsOneWidget);
    await tester.tap(find.text('Thêm vào phiếu'));
    await tester.pumpAndSettle();

    expect(find.text('10,5 kg × 8.000đ'), findsOneWidget);
    await tester.tap(find.text('Lưu phiếu'));
    await tester.pumpAndSettle();

    // Chuyển sang màn chi tiết phiếu vừa lưu.
    expect(find.text('Chi tiết phiếu thu mua'), findsOneWidget);
    expect(find.textContaining('TM-'), findsWidgets);
    expect(find.text('Chú Ba'), findsOneWidget);

    // Quay về danh sách, rồi sang tab Kho hàng.
    // Không dùng tester.pageBack(): hàm đó tìm tooltip tiếng Anh "Back".
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chú Ba'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Kho hàng'));
    await tester.pumpAndSettle();
    expect(find.text('10,5 kg'), findsOneWidget);
  });

  testWidgets('Báo lỗi khi thêm trùng tên', (tester) async {
    await openProducts(tester);
    await tester.tap(find.text('Thêm mặt hàng'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên mặt hàng *'),
      'sắt',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Mặt hàng "sắt" đã tồn tại'), findsOneWidget);
    // Vẫn ở lại form để người dùng sửa.
    expect(find.text('Thêm mặt hàng'), findsWidgets);
  });
}
