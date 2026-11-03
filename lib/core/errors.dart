/// Lỗi nghiệp vụ có thông báo thân thiện, hiển thị thẳng cho người dùng.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Chuyển mọi lỗi thành câu thông báo dễ hiểu.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  return 'Đã xảy ra lỗi, vui lòng thử lại.\n($error)';
}
