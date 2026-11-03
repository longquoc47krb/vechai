import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Sinh mã phiếu tiếp theo theo ngày: `PREFIX-yyyyMMdd-001`, 002...
/// Phải gọi trong transaction để 2 phiếu không bị trùng mã.
Future<String> nextDocumentCode(
  DatabaseExecutor txn, {
  required String table,
  required String prefix,
  required DateTime date,
}) async {
  final day = toDbDate(date).substring(0, 10).replaceAll('-', '');
  final start = '$prefix-$day-';
  final rows = await txn.rawQuery(
    'SELECT MAX(code) AS max_code FROM $table WHERE code LIKE ?',
    ['$start%'],
  );
  final maxCode = rows.first['max_code'] as String?;
  final next = maxCode == null
      ? 1
      : int.parse(maxCode.substring(start.length)) + 1;
  return '$start${next.toString().padLeft(3, '0')}';
}
