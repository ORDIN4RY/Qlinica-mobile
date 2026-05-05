class AttendanceRecord {
  final DateTime date;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final bool isPresent; // Can be false if absent
  
  // Location and photo data
  final double? latitude;
  final double? longitude;
  final String? photoPath;
  final bool? isLocationValid;

  AttendanceRecord({
    required this.date,
    this.clockInTime,
    this.clockOutTime,
    this.isPresent = true,
    this.latitude,
    this.longitude,
    this.photoPath,
    this.isLocationValid,
  });

  // copyWith for easy updates
  AttendanceRecord copyWith({
    DateTime? date,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    bool? isPresent,
    double? latitude,
    double? longitude,
    String? photoPath,
    bool? isLocationValid,
  }) {
    return AttendanceRecord(
      date: date ?? this.date,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      isPresent: isPresent ?? this.isPresent,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
      isLocationValid: isLocationValid ?? this.isLocationValid,
    );
  }
}
