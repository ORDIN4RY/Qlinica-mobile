enum LeaveType {
  sick('Sakit'),
  annual('Cuti Tahunan'),
  permission('Izin');

  final String label;
  const LeaveType(this.label);
}

enum LeaveStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak');

  final String label;
  const LeaveStatus(this.label);
}

class LeaveRequest {
  final String id;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    required this.createdAt,
  });
}
