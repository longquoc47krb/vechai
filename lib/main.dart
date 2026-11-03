import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp dữ liệu ngày tháng tiếng Việt cho package intl (tên thứ, tháng...).
  await initializeDateFormatting('vi');
  Intl.defaultLocale = 'vi';

  // ProviderScope là "kho chứa" mọi provider của Riverpod, phải bọc ngoài cùng.
  runApp(const ProviderScope(child: VeChaiApp()));
}
