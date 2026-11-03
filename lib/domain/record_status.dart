/// Trạng thái phiếu (dùng chung cho thu mua, bán, chi phí).
/// Phiếu không bao giờ bị xóa, chỉ chuyển sang [cancelled].
enum RecordStatus {
  active,
  cancelled;

  static RecordStatus parse(String value) =>
      value == 'cancelled' ? cancelled : active;
}
