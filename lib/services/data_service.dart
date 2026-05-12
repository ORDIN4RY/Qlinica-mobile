import 'package:flutter/foundation.dart';
import '../models/attendance_record.dart';
import '../models/leave_request.dart';

class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();

  factory DataService() {
    return _instance;
  }

  DataService._internal() {
    // Generate some mock history
    _generateMockData();
  }

  final List<AttendanceRecord> _attendanceHistory = [];
  final List<LeaveRequest> _leaveRequests = [];

  AttendanceRecord? _todayRecord;

  // Jam minimal absen pulang bisa muncul (default 15:00)
  int _clockOutAllowedHour = 15;
  int _clockOutAllowedMinute = 0;

  List<AttendanceRecord> get attendanceHistory => _attendanceHistory;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  AttendanceRecord? get todayRecord => _todayRecord;

  int get clockOutAllowedHour => _clockOutAllowedHour;
  int get clockOutAllowedMinute => _clockOutAllowedMinute;

  bool get hasClockedIn => _todayRecord?.clockInTime != null;
  bool get hasClockedOut => _todayRecord?.clockOutTime != null;

  /// Returns true jika jam saat ini sudah boleh absen pulang
  bool get canClockOut {
    final now = DateTime.now();
    final allowedTime = DateTime(now.year, now.month, now.day, _clockOutAllowedHour, _clockOutAllowedMinute);
    return now.isAfter(allowedTime) || now.isAtSameMomentAs(allowedTime);
  }

  /// Update jam minimal absen pulang
  void setClockOutAllowedTime(int hour, int minute) {
    _clockOutAllowedHour = hour;
    _clockOutAllowedMinute = minute;
    notifyListeners();
  }

  void _generateMockData() {
    final now = DateTime.now();

    // Create mock attendance for past 90 days
    for (int i = 1; i <= 90; i++) {
      final date = now.subtract(Duration(days: i));
      // Skip weekends (simplified)
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;

      _attendanceHistory.add(
        AttendanceRecord(
          date: date,
          clockInTime: DateTime(date.year, date.month, date.day, 8, 0),
          clockOutTime: DateTime(date.year, date.month, date.day, 17, 0),
        ),
      );
    }
    // Sort descending
    _attendanceHistory.sort((a, b) => b.date.compareTo(a.date));

    // Create mock leave requests
    _leaveRequests.addAll([
      LeaveRequest(
        id: '1',
        type: LeaveType.annual,
        startDate: now.subtract(const Duration(days: 15)),
        endDate: now.subtract(const Duration(days: 13)),
        reason: 'Acara keluarga',
        status: LeaveStatus.approved,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      LeaveRequest(
        id: '2',
        type: LeaveType.sick,
        startDate: now.subtract(const Duration(days: 45)),
        endDate: now.subtract(const Duration(days: 45)),
        reason: 'Demam',
        status: LeaveStatus.approved,
        createdAt: now.subtract(const Duration(days: 46)),
      ),
      LeaveRequest(
        id: '3',
        type: LeaveType.permission,
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.subtract(const Duration(days: 2)),
        reason: 'Urusan administrasi',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);

    // Initialize today record based on current time
    _todayRecord = AttendanceRecord(date: DateTime(now.year, now.month, now.day));
  }

  void clockIn({double? latitude, double? longitude, String? photoPath, bool? isLocationValid}) {
    if (_todayRecord == null) {
      final now = DateTime.now();
      _todayRecord = AttendanceRecord(date: DateTime(now.year, now.month, now.day));
    }

    if (!hasClockedIn) {
      _todayRecord = _todayRecord!.copyWith(
        clockInTime: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        photoPath: photoPath,
        isLocationValid: isLocationValid,
      );

      // Tambahkan ke history (posisi pertama, hari ini)
      // Hapus entry hari ini jika sudah ada supaya tidak duplikat
      final today = DateTime.now();
      _attendanceHistory.removeWhere(
        (r) => r.date.year == today.year && r.date.month == today.month && r.date.day == today.day,
      );
      _attendanceHistory.insert(0, _todayRecord!);

      notifyListeners();
    }
  }

  void clockOut({double? latitude, double? longitude, String? photoPath, bool? isLocationValid}) {
    if (hasClockedIn && !hasClockedOut) {
      _todayRecord = _todayRecord!.copyWith(
        clockOutTime: DateTime.now(),
        // Update foto & lokasi absen pulang jika ada
        latitude: latitude ?? _todayRecord!.latitude,
        longitude: longitude ?? _todayRecord!.longitude,
      );

      // Update atau insert entry hari ini di history
      final today = DateTime.now();
      final existingIndex = _attendanceHistory.indexWhere(
        (r) => r.date.year == today.year && r.date.month == today.month && r.date.day == today.day,
      );

      if (existingIndex >= 0) {
        _attendanceHistory[existingIndex] = _todayRecord!;
      } else {
        _attendanceHistory.insert(0, _todayRecord!);
      }

      notifyListeners();
    }
  }

  void addLeaveRequest(LeaveRequest request) {
    _leaveRequests.insert(0, request);
    notifyListeners();
  }
}
