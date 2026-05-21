import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:get/get.dart';

class AttendanceProcessScreen extends StatefulWidget {
  final bool isClockIn;
  final DateTime? shiftStartTime;

  const AttendanceProcessScreen({super.key, required this.isClockIn, this.shiftStartTime});

  @override
  State<AttendanceProcessScreen> createState() =>
      _AttendanceProcessScreenState();
}

class _AttendanceProcessScreenState extends State<AttendanceProcessScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Office Location (Gedung Jurusan TI Politeknik Negeri Jember)
  // final double officeLat = -8.1575886;
  // final double officeLng = 113.722782;
  // final double radiusInMeters = 100;

  final double officeLat = -8.1646404;
  final double officeLng = 113.7091021;
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

      if (position.isMocked) {
        setState(() {
          _locationError = 'Terdeteksi menggunakan Fake GPS / Mock Location!';
          _isLoadingLocation = false;
          _currentPosition = null;
        });
        return;
      }

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
        Get.snackbar(
          'Gagal',
          'Gagal mengambil foto. Pastikan kamera tersedia dan izin diberikan.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _submitAttendance() async {
    if (_imageFile == null || _imageBytes == null) {
      Get.snackbar('Peringatan', 'Harap ambil foto terlebih dahulu!', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (_currentPosition == null) {
      Get.snackbar('Peringatan', 'Lokasi belum ditemukan!', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    bool isLocationValid = _distanceFromOffice <= radiusInMeters;

    if (!isLocationValid) {
      Get.snackbar('Gagal', 'Anda di luar area klinik! Tidak bisa absen.', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      if (widget.isClockIn) {
        final result = await ApiService.instance.clockIn(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          isLocationValid: isLocationValid,
        );
        if (mounted) {
          final msg = result.telatMenit > 0
              ? 'Absen Masuk Berhasil! (Telat ${result.telatMenit} menit)'
              : 'Absen Masuk Berhasil!';
          Get.snackbar(
            'Absen Berhasil',
            msg,
            backgroundColor: result.telatMenit > 0 ? Colors.orange : Colors.green,
            colorText: Colors.white,
          );
        }
      } else {
        await ApiService.instance.clockOut(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          isLocationValid: isLocationValid,
        );
        if (mounted) {
          Get.snackbar('Berhasil', 'Absen Pulang Berhasil!', backgroundColor: Colors.green, colorText: Colors.white);
        }
      }
    } catch (e) {
      if (mounted) {
          Get.snackbar('Gagal', e.toString().replaceFirst('Exception: ', ''), backgroundColor: Colors.red, colorText: Colors.white);
      }
    }

    Get.back(result: true);
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
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderCard(title),
            const SizedBox(height: 16),
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
          if (widget.isClockIn && widget.shiftStartTime != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final isLate = (_currentTime.hour * 60 + _currentTime.minute) >
                    (widget.shiftStartTime!.hour * 60 + widget.shiftStartTime!.minute);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLate ? Icons.warning : Icons.check_circle,
                        color: isLate ? Colors.orange : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLate ? 'Telat' : 'Tepat Waktu',
                        style: TextStyle(
                          color: isLate ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
              color: const Color(0xFF1E3A8A).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E3A8A).withOpacity(0.2),
              ),
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
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF1E3A8A),
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
    bool isLocationValid = _distanceFromOffice <= radiusInMeters;
    bool canSubmit = hasPhoto && hasLocation && isLocationValid;

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
            if (!isLocationValid && hasLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Anda di luar area klinik (${_distanceFromOffice.toStringAsFixed(0)}m)',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canSubmit ? _submitAttendance : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(
                  canSubmit
                      ? title
                      : (isLocationValid
                            ? title
                            : 'Tidak Bisa Absen (Luar Area)'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
