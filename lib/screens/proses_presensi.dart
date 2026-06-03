import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'package:get/get.dart';
import '../controllers/presensi_controller.dart';

class AttendanceProcessScreen extends StatefulWidget {
  final bool isClockIn;
  final DateTime? shiftStartTime;

  const AttendanceProcessScreen({
    super.key,
    required this.isClockIn,
    this.shiftStartTime,
  });

  @override
  State<AttendanceProcessScreen> createState() =>
      _AttendanceProcessScreenState();
}

class _AttendanceProcessScreenState extends State<AttendanceProcessScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Nilai default — akan di-overwrite dari API saat initState
  double officeLat = -8.164423;
  double officeLng = 113.709018;
  double radiusInMeters = 100;
  bool _isSettingsLoaded = false;

  Position? _currentPosition;
  double _distanceFromOffice = 0;
  bool _isLoadingLocation = true;
  String _locationError = '';
  bool _isSubmitting = false;
  bool _useFrontCamera = true;

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

    _loadSettings();
    _retrieveLostData();
  }

  /// Fetch koordinat klinik & radius dari API agar tidak hardcode
  Future<void> _loadSettings() async {
    try {
      final data = await ApiService.instance.getPresensiSettings();
      final lokasi = data['lokasi'] as Map<String, dynamic>?;
      if (lokasi != null && mounted) {
        setState(() {
          officeLat       = (lokasi['latitude']  as num).toDouble();
          officeLng       = (lokasi['longitude'] as num).toDouble();
          radiusInMeters  = (lokasi['radius']    as num).toDouble();
          _isSettingsLoaded = true;
        });
      }
    } catch (_) {
      // Gagal fetch = pakai nilai default, tidak masalah
      if (mounted) setState(() => _isSettingsLoaded = true);
    }
    // Mulai deteksi lokasi setelah settings siap
    _getCurrentLocation();
  }

  Future<void> _retrieveLostData() async {
    if (kIsWeb) return;
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final bytes = await response.file!.readAsBytes();
        setState(() {
          _imageFile = response.file;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error retrieving lost camera data: $e');
    }
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
        preferredCameraDevice: _useFrontCamera
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _imageFile = photo;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
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
      Get.snackbar(
        'Peringatan',
        'Harap ambil foto terlebih dahulu!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (_currentPosition == null) {
      Get.snackbar(
        'Peringatan',
        'Lokasi belum ditemukan!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    bool isLocationValid = _distanceFromOffice <= radiusInMeters;

    if (!isLocationValid) {
      Get.snackbar(
        'Gagal',
        'Anda di luar area klinik! Tidak bisa absen.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.isClockIn) {
        final result = await ApiService.instance.clockIn(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          isLocationValid: isLocationValid,
        );

        // Batalkan semua notifikasi alpa karena sudah berhasil clock in
        await NotificationService.instance.batalkanNotifikasiAlpa();

        // Perbarui status presensi di controller secara reaktif agar dashboard berubah instan
        if (Get.isRegistered<PresensiController>()) {
          Get.find<PresensiController>().setStatusPresensi(
            masuk: true,
            pulang: false,
          );
          Get.find<PresensiController>().loadTodayStatus(); // background sync
        }

        final isLate = result.telatMenit > 0;
        final msg = isLate
            ? 'Absen Masuk Berhasil! (Telat ${result.telatMenit} menit)'
            : 'Absen Masuk Berhasil!';

        if (mounted) Get.back(result: true);
        Get.snackbar(
          'Absen Berhasil',
          msg,
          backgroundColor: isLate ? Colors.orange : Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        await ApiService.instance.clockOut(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          isLocationValid: isLocationValid,
        );

        // Perbarui status presensi di controller secara reaktif agar dashboard berubah instan
        if (Get.isRegistered<PresensiController>()) {
          Get.find<PresensiController>().setStatusPresensi(
            masuk: true,
            pulang: true,
          );
          Get.find<PresensiController>().loadTodayStatus(); // background sync
        }

        if (mounted) Get.back(result: true);
        Get.snackbar(
          'Berhasil',
          'Absen Pulang Berhasil!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Get.snackbar(
          'Gagal',
          e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLocationValid = _distanceFromOffice <= radiusInMeters;
    final isClockIn = widget.isClockIn;
    final accentColor = isClockIn ? const Color(0xFF1E3A8A) : Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(accentColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  _buildTimeCard(accentColor),
                  const SizedBox(height: 12),
                  _buildLocationCard(isLocationValid),
                  const SizedBox(height: 12),
                  _buildPhotoCard(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(accentColor),
    );
  }

  Widget _buildHeader(Color accentColor) {
    final title = widget.isClockIn ? 'Absen Masuk' : 'Absen Pulang';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 52, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isClockIn
              ? [const Color(0xFF1E3A8A), const Color(0xFF1565C0)]
              : [const Color(0xFFE65100), const Color(0xFFF57C00)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            widget.isClockIn ? Icons.login : Icons.logout,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEEE, dd MMM yyyy', 'id').format(_currentTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('HH:mm:ss', 'id').format(_currentTime),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.isClockIn && widget.shiftStartTime != null) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final isLate = _currentTime.isAfter(widget.shiftStartTime!);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isLate ? Colors.orange : const Color(0xFF2E7D32))
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isLate ? Colors.orange : const Color(0xFF2E7D32))
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLate
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: isLate ? Colors.orange : const Color(0xFF2E7D32),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLate ? 'Telat dari jadwal shift' : 'Tepat Waktu',
                        style: TextStyle(
                          color: isLate
                              ? Colors.orange
                              : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF1E3A8A), size: 18),
              SizedBox(width: 8),
              Text(
                'Status Lokasi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingLocation)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_locationError.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationError,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Coba Lagi',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isLocationValid
                    ? const Color(0xFF2E7D32).withOpacity(0.07)
                    : Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLocationValid
                      ? const Color(0xFF2E7D32).withOpacity(0.25)
                      : Colors.red.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLocationValid
                          ? const Color(0xFF2E7D32).withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLocationValid ? Icons.check_circle : Icons.cancel,
                      color: isLocationValid
                          ? const Color(0xFF2E7D32)
                          : Colors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLocationValid
                              ? 'Dalam Area Klinik'
                              : 'Di Luar Area Klinik',
                          style: TextStyle(
                            color: isLocationValid
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Jarak: ${_distanceFromOffice.toStringAsFixed(0)}m dari kantor',
                          style: TextStyle(
                            color: isLocationValid
                                ? const Color(0xFF2E7D32).withOpacity(0.8)
                                : Colors.red.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isLocationValid
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: isLocationValid
                            ? const Color(0xFF2E7D32)
                            : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const SizedBox(width: 12),
                const Icon(Icons.radar, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Radius ${radiusInMeters.toInt()}m',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.camera_alt, color: Color(0xFF1E3A8A), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Foto Absensi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              // Camera switch button
              GestureDetector(
                onTap: () => setState(() => _useFrontCamera = !_useFrontCamera),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1E3A8A).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useFrontCamera
                            ? Icons.camera_front
                            : Icons.camera_rear,
                        size: 14,
                        color: const Color(0xFF1E3A8A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _useFrontCamera ? 'Kamera Depan' : 'Kamera Belakang',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Photo preview area
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _imageBytes != null
                    ? const Color(0xFF2E7D32).withOpacity(0.4)
                    : const Color(0xFF1E3A8A).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF1E3A8A),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum Ada Foto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pastikan wajah terlihat jelas',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: Text(
                _imageBytes != null ? 'Ulangi Foto' : 'Ambil Foto',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _imageBytes != null
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color accentColor) {
    final title = widget.isClockIn ? 'Absen Masuk' : 'Absen Pulang';
    final bool hasPhoto = _imageBytes != null;
    final bool hasLocation = _currentPosition != null;
    final bool isLocationValid =
        hasLocation && _distanceFromOffice <= radiusInMeters;
    final bool canSubmit =
        hasPhoto && hasLocation && isLocationValid && !_isSubmitting;

    String buttonLabel;
    if (!hasPhoto) {
      buttonLabel = 'Harap Ambil Foto';
    } else if (!hasLocation) {
      buttonLabel = _isLoadingLocation
          ? 'Mencari Lokasi...'
          : 'Lokasi Tidak Ditemukan';
    } else if (!isLocationValid) {
      buttonLabel = 'Di Luar Area Klinik';
    } else {
      buttonLabel = title;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLocationValid && hasLocation && !_isLoadingLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
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
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit ? _submitAttendance : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit
                      ? accentColor
                      : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: canSubmit ? 2 : 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        buttonLabel,
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
