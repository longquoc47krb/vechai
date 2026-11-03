import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/local/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp dữ liệu ngày tháng tiếng Việt cho package intl (tên thứ, tháng...).
  await initializeDateFormatting('vi');
  Intl.defaultLocale = 'vi';

  // Mở SQLite một lần khi khởi động; lần đầu sẽ tạo bảng + mặt hàng mẫu.
  final database = await AppDatabase.open();

  // ProviderScope là "kho chứa" mọi provider của Riverpod, phải bọc ngoài cùng.
  // overrideWithValue đưa database đã mở vào để các repository dùng chung.
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const VeChaiApp(),
    ),
  );
}
