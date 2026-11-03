const _withDiacritics =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _withoutDiacritics =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Chuẩn hóa để tìm kiếm / so sánh: chữ thường, bỏ dấu, gộp khoảng trắng.
/// Ví dụ: "  Sắt  Vụn " -> "sat vun".
String normalizeForSearch(String input) {
  final lower = input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = _withDiacritics.indexOf(char);
    buffer.write(index >= 0 ? _withoutDiacritics[index] : char);
  }
  return buffer.toString();
}
