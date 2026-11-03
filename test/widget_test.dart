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
    expect(find.textContaining('Chưa có phiếu thu mua hay bán'), findsOneWidget);
    // Phần giải thích cách tính nằm cuối trang -> cuộn xuống.
    await tester.scrollUntilVisible(
      find.text('Cách tính'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cách tính'), findsOneWidget);

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

    expect(find.text('Đã thêm mặt hàng Dây điện'), findsOneWidget);
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

    // Thêm dòng: gõ "sat" -> chọn gợi ý "Sắt", giá 8.000đ tự điền.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm mặt hàng'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mặt hàng *'),
      'sat',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sắt'));
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

    // Báo cáo tháng này và Trang chủ tự cập nhật: lợi nhuận = 0 − 84.000đ.
    await tester.tap(find.widgetWithText(NavigationDestination, 'Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('-84.000đ'), findsWidgets);
    expect(find.text('1 phiếu thu mua'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('84.000đ'), findsOneWidget);
  });

  testWidgets('Đang tạo phiếu thu mua: tạo mặt hàng mới từ ô gợi ý', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Thu mua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo phiếu thu mua'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Người bán (không bắt buộc)'),
      'Cô Hai',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm mặt hàng'));
    await tester.pumpAndSettle();

    // Gõ tên chưa có -> không có gợi ý, có dòng "Thêm mặt hàng mới".
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mặt hàng *'),
      'Dây điện',
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy "Dây điện"'), findsOneWidget);

    // Bấm "Lưu" khi chưa chọn mặt hàng -> báo lỗi.
    await tester.tap(find.text('Thêm vào phiếu'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mặt hàng trong danh sách gợi ý'), findsOneWidget);

    await tester.tap(find.text('Thêm mặt hàng mới "Dây điện"'));
    await tester.pumpAndSettle();

    // Form mặt hàng mở với tên điền sẵn.
    expect(find.text('Thêm mặt hàng'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Dây điện'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giá thu mua mặc định'),
      '15000',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    // Quay lại bảng chọn: mặt hàng mới đã được chọn, giá tự điền.
    expect(find.text('Đơn giá / kg'), findsOneWidget);
    expect(find.text('15.000'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số lượng *'),
      '2',
    );
    await tester.tap(find.text('Thêm vào phiếu'));
    await tester.pumpAndSettle();

    // Phiếu đang nhập dở vẫn còn nguyên.
    expect(find.text('Cô Hai'), findsOneWidget);
    expect(find.text('Dây điện'), findsOneWidget);
    expect(find.text('30.000đ'), findsWidgets);
  });

  testWidgets('Tạo phiếu bán chỉ nhập tổng tiền, rồi hủy phiếu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Bán hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo phiếu bán'));
    await tester.pumpAndSettle();

    // Lưu khi chưa nhập tiền -> báo lỗi, không lưu.
    await tester.tap(find.text('Lưu phiếu bán'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tổng tiền bán'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tổng tiền bán *'),
      '1200000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Người mua (không bắt buộc)'),
      'Minh Phát',
    );
    await tester.tap(find.text('Lưu phiếu bán'));
    await tester.pumpAndSettle();

    // Về danh sách, thấy phiếu vừa tạo.
    expect(find.text('Minh Phát'), findsOneWidget);
    expect(find.text('1.200.000đ'), findsWidgets);

    // Mở chi tiết -> Hủy phiếu (có xác nhận).
    await tester.tap(find.text('Minh Phát'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy phiếu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không còn được tính vào'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy phiếu'));
    await tester.pumpAndSettle();
    expect(find.text('Phiếu đã hủy'), findsOneWidget);

    // Danh sách mặc định ẩn phiếu đã hủy.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Minh Phát'), findsNothing);
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
