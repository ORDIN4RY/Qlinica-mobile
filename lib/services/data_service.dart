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

  List<AttendanceRecord> get attendanceHistory => _attendanceHistory;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  AttendanceRecord? get todayRecord => _todayRecord;

  bool get hasClockedIn => _todayRecord?.clockInTime != null;
  bool get hasClockedOut => _todayRecord?.clockOutTime != null;

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
        )
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
      notifyListeners();
    }
  }

  void clockOut({double? latitude, double? longitude, String? photoPath, bool? isLocationValid}) {
    if (hasClockedIn && !hasClockedOut) {
      _todayRecord = _todayRecord!.copyWith(
        clockOutTime: DateTime.now(),
        // We could also update lat/lng here, but let's just keep the clock out time 
        // or overwrite if needed. For simplicity, just clock out.
      );
      
      // Also add to history
      _attendanceHistory.insert(0, _todayRecord!);
      
      notifyListeners();
    }
  }

  void addLeaveRequest(LeaveRequest request) {
    _leaveRequests.insert(0, request);
    notifyListeners();
  }
}
