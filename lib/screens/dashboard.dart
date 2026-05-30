import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import 'proses_presensi.dart';
import 'login_screen.dart';
import 'package:get/get.dart';
import '../controllers/presensi_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  UserModel? _currentUser;

  // Controller presensi reaktif
  final PresensiController _presensiCtrl = Get.put(PresensiController());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });

    // Load user info
    ApiService.instance.getSavedUser().then((user) {
      if (mounted) setState(() => _currentUser = user);
    });

    // Load status presensi hari ini
    _loadTodayStatus();
  }

  /// Mengatur jadwal notifikasi absensi dinamis berdasarkan shift masing-masing pegawai.
  Future<void> _jadwalkanNotifikasiSesuaiShift() async {
    // 1. Batalkan notifikasi presensi masa depan secara surgical agar tidak menghapus notifikasi penting lainnya (seperti cuti disetujui)
    await NotificationService.instance.batalkanNotifikasiPresensiMendatang();

    // 2. Bersihkan notifikasi presensi kedaluwarsa/hari-hari kemarin yang masih menggantung di status bar
    await NotificationService.instance.bersihkanNotifikasiKedaluwarsa();

    final jadwalToday = _presensiCtrl.rxJadwalToday.value;
    final hasClockedIn = _presensiCtrl.hasClockedIn.value;
    final hasClockedOut = _presensiCtrl.hasClockedOut.value;
    final upcomingShifts = _presensiCtrl.rxUpcomingShifts.value;

    // 3. Jadwalkan pengingat untuk shift HARI INI
    if (jadwalToday != null) {
      final masukStr = jadwalToday['masuk']?.toString();
      final pulangStr = jadwalToday['pulang']?.toString();
      final shiftNamaRaw = jadwalToday['nama']?.toString() ?? 'Shift';
      final shiftNama = _translateShift(shiftNamaRaw);

      final today = DateTime.now();

      // Cek apakah hari ini bukan hari Libur
      if (!_isLibur(shiftNamaRaw)) {
        // A. Jadwalkan Absen Masuk (15 menit sebelum masuk shift)
        if (masukStr != null && masukStr.contains(':')) {
          try {
            final parts = masukStr.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final waktuMasuk = DateTime(today.year, today.month, today.day, h, m);
            final waktuPengingatMasuk = waktuMasuk.subtract(const Duration(minutes: 15));

            final idMasuk = (today.year * 10000 + today.month * 100 + today.day) * 2;

            // Hanya jadwalkan jika belum clock-in hari ini
            if (!hasClockedIn) {
              await NotificationService.instance.jadwalkanSekaliSpesifik(
                id: idMasuk,
                judul: '⏰ Pengingat Absen Masuk ($shiftNama)',
                isi: 'Shift Anda hari ini dimulai pukul $masukStr. Jangan lupa absen masuk!',
                waktu: waktuPengingatMasuk,
                channelId: 'sahaduta_presensi',
                channelName: 'Pengingat Presensi',
                payload: 'absen_masuk',
              );

              // 1 jam setelah masuk shift (Peringatan Belum Absen)
              final waktuPeringatanAlpa = waktuMasuk.add(const Duration(hours: 1));
              await NotificationService.instance.jadwalkanSekaliSpesifik(
                id: idMasuk + 100000, // ID unik pembeda
                judul: '⚠️ Kamu Belum Absen!',
                isi: 'Shift sudah dimulai tapi kamu belum clock in. Segera absen atau akan dicatat sebagai Alpa!',
                waktu: waktuPeringatanAlpa,
                channelId: 'sahaduta_presensi',
                channelName: 'Pengingat Presensi',
                payload: 'peringatan_alpa',
              );
            }
          } catch (e) {
            debugPrint('Error scheduling today clock-in notification: $e');
          }
        }

        // B. Jadwalkan Absen Pulang
        if (pulangStr != null && pulangStr.contains(':')) {
          try {
            final parts = pulangStr.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final waktuPulang = DateTime(today.year, today.month, today.day, h, m);

            final idPulang = (today.year * 10000 + today.month * 100 + today.day) * 2 + 1;

            // Hanya jadwalkan jika belum clock-out hari ini
            if (!hasClockedOut) {
              await NotificationService.instance.jadwalkanSekaliSpesifik(
                id: idPulang,
                judul: '🏠 Pengingat Absen Pulang ($shiftNama)',
                isi: 'Shift Anda hari ini selesai pukul $pulangStr. Jangan lupa absen pulang!',
                waktu: waktuPulang,
                channelId: 'sahaduta_presensi',
                channelName: 'Pengingat Presensi',
                payload: 'absen_pulang',
              );

              // 5 menit setelah pulang shift (Konfirmasi Alpa - jika tidak pernah clock in)
              if (!hasClockedIn) {
                final waktuKonfirmasiAlpa = waktuPulang.add(const Duration(minutes: 5));
                await NotificationService.instance.jadwalkanSekaliSpesifik(
                  id: idPulang + 200000, // ID unik
                  judul: '🚨 Status Alpa Tercatat',
                  isi: 'Anda tercatat Alpa karena tidak melakukan absensi pada shift hari ini.',
                  waktu: waktuKonfirmasiAlpa,
                  channelId: 'sahaduta_presensi',
                  channelName: 'Pengingat Presensi',
                  payload: 'konfirmasi_alpa',
                );
              }
            }
          } catch (e) {
            debugPrint('Error scheduling today clock-out notification: $e');
          }
        }
      }
    }

    // 3. Jadwalkan untuk SHIFT MINGGU INI (UPCOMING SHIFTS)
    if (upcomingShifts.isNotEmpty) {
      for (final shift in upcomingShifts) {
        try {
          final tglStr = shift['tanggal']?.toString(); // YYYY-MM-DD
          final jamStr = shift['jam']?.toString(); // "07:00 - 15:00" atau "Libur"
          final shiftNamaRaw = shift['shift']?.toString() ?? 'Shift';
          final shiftNama = _translateShift(shiftNamaRaw);

          if (tglStr == null || jamStr == null || _isLibur(jamStr) || _isLibur(shiftNamaRaw)) continue;

          final shiftDate = DateTime.parse(tglStr);

          // Lewati jika hari ini (sudah dihandle di atas agar sinkron dengan status clock-in/out hari ini)
          final today = DateTime.now();
          if (shiftDate.year == today.year && shiftDate.month == today.month && shiftDate.day == today.day) {
            continue;
          }

          // Parse jam masuk & pulang, contoh "07:00 - 15:00"
          final timeParts = jamStr.split('-');
          if (timeParts.length < 2) continue;

          final masukStr = timeParts[0].trim(); // "07:00"
          final pulangStr = timeParts[1].trim(); // "15:00"

          // Format tanggal Bahasa Indonesia untuk pesan notifikasi
          final formattedTgl = DateFormat('EEEE, d MMMM yyyy', 'id').format(shiftDate);

          // A. Jadwalkan Pengingat Masuk (15 menit sebelum shift)
          if (masukStr.contains(':')) {
            final parts = masukStr.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final waktuMasuk = DateTime(shiftDate.year, shiftDate.month, shiftDate.day, h, m);
            final waktuPengingatMasuk = waktuMasuk.subtract(const Duration(minutes: 15));

            final idMasuk = (shiftDate.year * 10000 + shiftDate.month * 100 + shiftDate.day) * 2;

            await NotificationService.instance.jadwalkanSekaliSpesifik(
              id: idMasuk,
              judul: '⏰ Pengingat Absen Masuk ($shiftNama)',
              isi: 'Shift Anda pada $formattedTgl dimulai pukul $masukStr. Jangan lupa absen masuk!',
              waktu: waktuPengingatMasuk,
              channelId: 'sahaduta_presensi',
              channelName: 'Pengingat Presensi',
              payload: 'absen_masuk',
            );

            // 1 jam setelah masuk shift (Peringatan Belum Absen)
            final waktuPeringatanAlpa = waktuMasuk.add(const Duration(hours: 1));
            await NotificationService.instance.jadwalkanSekaliSpesifik(
              id: idMasuk + 100000,
              judul: '⚠️ Kamu Belum Absen!',
              isi: 'Shift sudah dimulai tapi kamu belum clock in. Segera absen atau akan dicatat sebagai Alpa!',
              waktu: waktuPeringatanAlpa,
              channelId: 'sahaduta_presensi',
              channelName: 'Pengingat Presensi',
              payload: 'peringatan_alpa',
            );
          }

          // B. Jadwalkan Pengingat Pulang
          if (pulangStr.contains(':')) {
            final parts = pulangStr.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final waktuPulang = DateTime(shiftDate.year, shiftDate.month, shiftDate.day, h, m);

            final idPulang = (shiftDate.year * 10000 + shiftDate.month * 100 + shiftDate.day) * 2 + 1;

            await NotificationService.instance.jadwalkanSekaliSpesifik(
              id: idPulang,
              judul: '🏠 Pengingat Absen Pulang ($shiftNama)',
              isi: 'Shift Anda pada $formattedTgl selesai pukul $pulangStr. Jangan lupa absen pulang!',
              waktu: waktuPulang,
              channelId: 'sahaduta_presensi',
              channelName: 'Pengingat Presensi',
              payload: 'absen_pulang',
            );

            // 5 menit setelah pulang shift (Konfirmasi Alpa - jika tidak pernah clock in)
            final waktuKonfirmasiAlpa = waktuPulang.add(const Duration(minutes: 5));
            await NotificationService.instance.jadwalkanSekaliSpesifik(
              id: idPulang + 200000,
              judul: '🚨 Status Alpa Tercatat',
              isi: 'Anda tercatat Alpa karena tidak melakukan absensi pada shift ini.',
              waktu: waktuKonfirmasiAlpa,
              channelId: 'sahaduta_presensi',
              channelName: 'Pengingat Presensi',
              payload: 'konfirmasi_alpa',
            );
          }
        } catch (e) {
          debugPrint('Error scheduling upcoming shift notifications: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadTodayStatus() async {
    await _presensiCtrl.loadTodayStatus();
    if (mounted) {
      // Sesuaikan jadwal notifikasi dengan shift aktual dari API
      _jadwalkanNotifikasiSesuaiShift();

      // Periksa apakah ada perubahan status cuti/izin/sakit dari admin
      NotificationService.instance.periksaPerubahanStatusCuti();

      // Sinkronisasi FCM Token perangkat ke server Laravel
      FcmService.instance.getAndSendToken();
    }
  }

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ApiService.instance.logout();
    if (!mounted) return;
    Get.offAll(() => const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Obx(() => Column(
        children: [
          _buildGreetingHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTimeHeader(),
                  const SizedBox(height: 20),
                  _buildAttendanceStatus(),
                  const SizedBox(height: 16),
                  _buildShiftInfo(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  // Bagian Jadwal Mendatang
                  _buildUpcomingSchedules(),
                  const SizedBox(height: 80), // Jarak ekstra agar enak di-scroll
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }

  Widget _buildGreetingHeader() {
    final name = _currentUser?.pegawai?['nama'] as String? ?? _currentUser?.name ?? 'Pegawai';
    final jabatan = _currentUser?.pegawai?['jabatan'] as String? ?? _currentUser?.role ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final greeting = _getGreeting();

    final fotoUrl = _currentUser?.foto;
    String? fullPhotoUrl;
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      if (fotoUrl.startsWith('http')) {
        fullPhotoUrl = fotoUrl;
      } else {
        final baseUrl = kBaseUrl.replaceAll('/api/mobile', '/storage');
        fullPhotoUrl = fotoUrl.startsWith('/') ? '$baseUrl$fotoUrl' : '$baseUrl/$fotoUrl';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
              image: fullPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(fullPhotoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: fullPhotoUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (jabatan.isNotEmpty)
                  Text(
                    jabatan,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = _currentTime.hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  String _translateShift(String? shift) {
    if (shift == null) return 'Shift';
    final s = shift.toLowerCase().trim();
    if (s == 'off' || s == 'holiday' || s == 'libur' || s == 'free') {
      return 'Libur';
    }
    if (s == 'morning shift' || s == 'morning') {
      return 'Shift Pagi';
    }
    if (s == 'day shift' || s == 'day') {
      return 'Shift Siang';
    }
    if (s == 'night shift' || s == 'night') {
      return 'Shift Malam';
    }
    if (s == 'evening shift' || s == 'evening' || s == 'afternoon') {
      return 'Shift Sore';
    }
    return shift;
  }

  String _translateJam(String? jam) {
    if (jam == null) return '--:--';
    final j = jam.toLowerCase().trim();
    if (j == 'off' || j == 'holiday' || j == 'libur' || j == 'free') {
      return 'Libur';
    }
    return jam;
  }

  bool _isLibur(String? value) {
    if (value == null) return true;
    final v = value.toLowerCase();
    return v.contains('libur') ||
        v.contains('off') ||
        v.contains('holiday') ||
        v.contains('free');
  }

  Widget _buildTimeHeader() {
    return Column(
      children: [
        Text(
          DateFormat('HH:mm:ss', 'id').format(_currentTime),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, dd MMMM yyyy', 'id').format(_currentTime),
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatus() {
    if (_presensiCtrl.isLoadingStatus.value) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Format jam masuk & keluar
    String clockInTime = '--:--';
    String clockOutTime = '--:--';
    String? telatInfo;

    final todayRecord = _presensiCtrl.rxTodayRecord.value;
    if (todayRecord != null) {
      if (todayRecord.jamMasuk != null) {
        clockInTime = todayRecord.jamMasuk!.substring(0, 5);
      }
      if (todayRecord.jamKeluar != null) {
        clockOutTime = todayRecord.jamKeluar!.substring(0, 5);
      }
      if (todayRecord.telatMenit > 0) {
        telatInfo = 'Telat ${todayRecord.telatMenit} menit';
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusColumn('Masuk', clockInTime, Icons.login, const Color(0xFF2E7D32)),
                Container(width: 1, height: 50, color: Colors.grey.shade300),
                _buildStatusColumn('Pulang', clockOutTime, Icons.logout, Colors.orange),
              ],
            ),
            if (telatInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57C00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF57C00).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFFF57C00)),
                    const SizedBox(width: 6),
                    Text(
                      telatInfo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF57C00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
     );
  }

  Widget _buildShiftInfo() {
    if (_presensiCtrl.isLoadingStatus.value) return const SizedBox.shrink();

    final jadwalToday = _presensiCtrl.rxJadwalToday.value;
    final hasJadwal = jadwalToday != null;
    final color = hasJadwal ? const Color(0xFF1E3A8A) : Colors.red;
    final bgColor = color.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(hasJadwal ? Icons.calendar_today : Icons.event_busy, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasJadwal ? 'Jadwal Shift Anda' : 'Status Jadwal',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasJadwal
                      ? '${_translateShift(jadwalToday['nama']?.toString())} (${jadwalToday['masuk']} - ${jadwalToday['pulang']})'
                      : 'Anda Libur / Tidak Ada Jadwal',
                  style: TextStyle(
                    fontSize: 15,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusColumn(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          time,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_presensiCtrl.isLoadingStatus.value) {
      return const SizedBox.shrink();
    }

    final jadwalToday = _presensiCtrl.rxJadwalToday.value;
    final bool isLibur = jadwalToday == null || _isLibur(jadwalToday['nama']?.toString());

    if (isLibur) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'TIDAK BISA ABSEN (LIBUR)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    // Parse jam masuk & pulang
    DateTime? shiftStartTime;
    final masukStr = jadwalToday['masuk']?.toString();
    if (masukStr != null && masukStr.contains(':')) {
      final parts = masukStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        shiftStartTime = DateTime(_currentTime.year, _currentTime.month, _currentTime.day, h, m);
      }
    }

    DateTime? shiftEndTime;
    final pulangStr = jadwalToday['pulang']?.toString();
    if (pulangStr != null && pulangStr.contains(':')) {
      final parts = pulangStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        shiftEndTime = DateTime(_currentTime.year, _currentTime.month, _currentTime.day, h, m);
      }
    }

    if (shiftStartTime != null && shiftEndTime != null) {
      if (shiftEndTime.isBefore(shiftStartTime)) {
        if (_currentTime.hour < shiftEndTime.hour || (_currentTime.hour == shiftEndTime.hour && _currentTime.minute < shiftEndTime.minute)) {
          shiftStartTime = shiftStartTime.subtract(const Duration(days: 1));
        } else {
          shiftEndTime = shiftEndTime.add(const Duration(days: 1));
        }
      }
    }

    final hasClockedIn = _presensiCtrl.hasClockedIn.value;
    final hasClockedOut = _presensiCtrl.hasClockedOut.value;

    if (!hasClockedIn) {
      if (shiftStartTime != null) {
        final allowedStartTime = shiftStartTime.subtract(const Duration(hours: 1));
        if (_currentTime.isBefore(allowedStartTime)) {
          final timeStr = DateFormat('HH:mm').format(allowedStartTime);
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'ABSEN DIBUKA PUKUL $timeStr',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          );
        }
      }

      return ElevatedButton(
        onPressed: () async {
          final result = await Get.to(() => AttendanceProcessScreen(
            isClockIn: true,
            shiftStartTime: shiftStartTime,
          ));
          if (result == true) _loadTodayStatus();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'CLOCK IN',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (!hasClockedOut) {
      if (shiftEndTime != null) {
        final allowedEndTime = shiftEndTime.subtract(const Duration(minutes: 10));
        if (_currentTime.isBefore(allowedEndTime)) {
          final timeStr = DateFormat('HH:mm').format(allowedEndTime);
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'ABSEN PULANG DIBUKA PUKUL $timeStr',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }
      }

      return ElevatedButton(
        onPressed: () async {
          final result = await Get.to(() => const AttendanceProcessScreen(isClockIn: false));
          if (result == true) _loadTodayStatus();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'CLOCK OUT',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '✓ Kehadiran Hari Ini Selesai',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildUpcomingSchedules() {
    final upcomingShifts = _presensiCtrl.rxUpcomingShifts.value;
    if (_presensiCtrl.isLoadingStatus.value || upcomingShifts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Jadwal Kerja Minggu Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...upcomingShifts.map((s) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(DateTime.parse(s['tanggal'])),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        DateFormat('MMM', 'id').format(DateTime.parse(s['tanggal'])),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE', 'id').format(DateTime.parse(s['tanggal'])),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        _translateShift(s['shift']?.toString()),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  _translateJam(s['jam']?.toString()),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1565C0)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
