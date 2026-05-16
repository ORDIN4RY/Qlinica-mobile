import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart';

class AttendanceProcessScreen extends StatefulWidget {
  final bool isClockIn;

  const AttendanceProcessScreen({super.key, required this.isClockIn});

  @override
  State<AttendanceProcessScreen> createState() =>
      _AttendanceProcessScreenState();
}

class _AttendanceProcessScreenState extends State<AttendanceProcessScreen> {
  final DataService _dataService = DataService();
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Office Location (Gedung Jurusan TI Politeknik Negeri Jember)
  final double officeLat = -8.1575886;
  final double officeLng = 113.722782;
  final double radiusInMeters = 100;

  Position? _currentPosition;
  double _distanceFromOffice = 0;
  bool _isLoadingLocation = true;
  String _locationError = '';

  // Gunakan XFile agar kompatibel Web & Mobile
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    _getCurrentLocation();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Layanan lokasi dinonaktifkan.';
        _isLoadingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Izin lokasi ditolak.';
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError =
            'Izin lokasi ditolak permanen, tidak dapat meminta izin.';
        _isLoadingLocation = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double distanceInMeters = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentPosition = position;
        _distanceFromOffice = distanceInMeters;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Gagal mendapatkan lokasi.';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (photo != null) {
        // Baca bytes agar bisa ditampilkan di Web maupun Mobile
        final bytes = await photo.readAsBytes();
        setState(() {
          _imageFile = photo;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        // Hindari string interpolation langsung pada $e di Flutter Web karena 
        // JS object undefined tidak memiliki method toString, memicu 'Symbol(dartx.toString)'
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto. Pastikan kamera tersedia dan izin diberikan.')),
        );
      }
    }
  }

  Future<void> _submitAttendance() async {
    if (_imageFile == null || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap ambil foto terlebih dahulu!')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lokasi belum ditemukan!')));
      return;
    }

    bool isLocationValid = _distanceFromOffice <= radiusInMeters;
    // Untuk Web gunakan path virtual; Mobile gunakan path asli
    final photoPath = kIsWeb ? 'web_photo_${DateTime.now().millisecondsSinceEpoch}' : _imageFile!.path;

    if (widget.isClockIn) {
      _dataService.clockIn(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photoPath: photoPath,
        isLocationValid: isLocationValid,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Absen Masuk Berhasil!')));
      }
    } else {
      _dataService.clockOut(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photoPath: photoPath,
        isLocationValid: isLocationValid,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Absen Pulang Berhasil!')));
      }
    }

    if (mounted) Navigator.pop(context);
  }

  /// Dialog pengaturan jam absen pulang (hanya ditampilkan saat isClockOut)
  Future<void> _showClockOutTimeSettings() async {
    int hour = _dataService.clockOutAllowedHour;
    int minute = _dataService.clockOutAllowedMinute;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: 'Atur Jam Minimal Absen Pulang',
    );

    if (picked != null) {
      _dataService.setClockOutAllowedTime(picked.hour, picked.minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Absen pulang diatur mulai pukul ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLocationValid = _distanceFromOffice <= radiusInMeters;
    String title = widget.isClockIn ? 'Absen Masuk' : 'Absen Pulang';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Tombol pengaturan jam hanya muncul di halaman Absen Pulang
          if (!widget.isClockIn)
            IconButton(
              onPressed: _showClockOutTimeSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Atur Jam Absen Pulang',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderCard(title),
            const SizedBox(height: 16),
            if (!widget.isClockIn) _buildClockOutTimeInfo(),
            if (!widget.isClockIn) const SizedBox(height: 16),
            _buildLocationCard(isLocationValid),
            const SizedBox(height: 16),
            _buildPhotoCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildHeaderCard(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71), // Green color matching design
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isClockIn ? Icons.login : Icons.logout,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('EEEE, dd MMM yyyy', 'id').format(_currentTime),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm:ss', 'id').format(_currentTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Info jam minimal absen pulang
  Widget _buildClockOutTimeInfo() {
    final allowedHour = _dataService.clockOutAllowedHour.toString().padLeft(2, '0');
    final allowedMinute = _dataService.clockOutAllowedMinute.toString().padLeft(2, '0');
    final canClockOut = _dataService.canClockOut;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: canClockOut ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canClockOut ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canClockOut ? Icons.check_circle_outline : Icons.access_time,
            color: canClockOut ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              canClockOut
                  ? 'Absen pulang sudah bisa dilakukan'
                  : 'Absen pulang tersedia mulai pukul $allowedHour:$allowedMinute',
              style: TextStyle(
                color: canClockOut ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _showClockOutTimeSettings,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Atur'),
            style: TextButton.styleFrom(
              foregroundColor: canClockOut ? Colors.green : Colors.orange,
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool isLocationValid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Status Lokasi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else if (_locationError.isNotEmpty)
            Center(
              child: Text(
                _locationError,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLocationValid
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLocationValid
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLocationValid ? Icons.check_circle : Icons.cancel,
                    color: isLocationValid ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLocationValid
                              ? 'Dalam Area Kantor'
                              : 'Luar Area Kantor',
                          style: TextStyle(
                            color: isLocationValid ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Jarak: ${_distanceFromOffice.toStringAsFixed(0)}m dari Kantor',
                          style: TextStyle(
                            color: isLocationValid
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'GPS: ${_currentPosition?.latitude.toStringAsFixed(6) ?? '-'}, ${_currentPosition?.longitude.toStringAsFixed(6) ?? '-'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.radar, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Radius: ${radiusInMeters.toInt()}m',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.blueGrey, size: 20),
              SizedBox(width: 8),
              Text(
                'Foto Absensi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // Gunakan Image.memory agar kompatibel Web & Mobile
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.blue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Siap Ambil Foto?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Pastikan wajah terlihat jelas',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera),
              label: Text(_imageBytes != null ? 'Ulangi Foto' : 'Ambil Foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    String title = widget.isClockIn ? 'Absen Masuk' : 'Absen Pulang';
    bool hasPhoto = _imageBytes != null;
    bool hasLocation = _currentPosition != null;
    bool timeAllowed = widget.isClockIn ? true : _dataService.canClockOut;
    bool canSubmit = hasPhoto && hasLocation && timeAllowed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isClockIn && !_dataService.canClockOut)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Absen pulang belum tersedia (mulai pukul ${_dataService.clockOutAllowedHour.toString().padLeft(2, '0')}:${_dataService.clockOutAllowedMinute.toString().padLeft(2, '0')})',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canSubmit ? _submitAttendance : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
