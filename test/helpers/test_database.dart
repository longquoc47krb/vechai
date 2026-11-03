import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vechai/data/local/app_database.dart';

/// Database SQLite trong RAM, mỗi lần gọi là một DB mới tinh (đã có seed).
/// Dùng bản "NoIsolate" để chạy được cả trong testWidgets (fake async).
Future<AppDatabase> openTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
}
