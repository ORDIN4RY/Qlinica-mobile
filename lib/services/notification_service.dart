import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Channel IDs ────────────────────────────────────────────────────────────
  static const String _channelIdGeneral = 'sahaduta_general';
  static const String _channelIdPresensi = 'sahaduta_presensi';

  // ─── Notification IDs ───────────────────────────────────────────────────────
  static const int idPengingatMasuk   = 1;
  static const int idPengingatPulang  = 2;
  static const int idPeringatanAlpa   = 3; // ← warning: belum absen 1 jam setelah shift
  static const int idKonfirmasiAlpa   = 4; // ← final: shift sudah selesai, status Alpa
  static const int idUmum             = 100;

  /// Panggil sekali saat app pertama kali berjalan (di main.dart).
  Future<void> init() async {
    if (_initialized) return;

    // Init timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Konfigurasi Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Konfigurasi iOS / macOS
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Minta izin di Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;

    // Bersihkan notifikasi kedaluwarsa secara otomatis saat aplikasi dimulai
    await bersihkanNotifikasiKedaluwarsa();
  }

  /// Callback saat notifikasi di-tap oleh user
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;

    // Saat user tap notifikasi konfirmasi alpa → laporkan ke backend
    if (payload == 'konfirmasi_alpa') {
      _kirimLaporanAlpa();
    }
    // Bisa navigate ke screen tertentu berdasarkan payload lainnya
    // Contoh: if (payload == 'absen_masuk') Get.toNamed('/presensi');
  }

  // ─── Detail channel ─────────────────────────────────────────────────────────

  AndroidNotificationDetails _androidDetail({
    required String channelId,
    required String channelName,
    String channelDescription = '',
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
  }

  // ─── 1. Notifikasi Langsung (Instan) ─────────────────────────────────────────

  /// Tampilkan notifikasi langsung (non-scheduled).
  Future<void> tampilkanNotifikasi({
    required int id,
    required String judul,
    required String isi,
    String? payload,
  }) async {
    final detail = NotificationDetails(
      android: _androidDetail(
        channelId: _channelIdGeneral,
        channelName: 'Notifikasi Umum',
        channelDescription: 'Notifikasi informasi umum dari Sahaduta',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(id, judul, isi, detail, payload: payload);
  }

  // ─── 2. Notifikasi Terjadwal Harian ──────────────────────────────────────────

  /// Jadwalkan notifikasi pengingat ABSEN MASUK setiap hari.
  ///
  /// [jam] dan [menit] adalah waktu dalam format 24 jam (WIB).
  /// Contoh: jam=7, menit=30 → setiap hari jam 07:30 WIB.
  Future<void> jadwalkanPengingatMasuk({int jam = 7, int menit = 30}) async {
    await _jadwalkanHarian(
      id: idPengingatMasuk,
      judul: '⏰ Pengingat Absen Masuk',
      isi: 'Jangan lupa absen masuk hari ini!',
      jam: jam,
      menit: menit,
      channelId: _channelIdPresensi,
      channelName: 'Pengingat Presensi',
      payload: 'absen_masuk',
    );
  }

  /// Jadwalkan notifikasi pengingat ABSEN PULANG setiap hari.
  Future<void> jadwalkanPengingatPulang({int jam = 17, int menit = 0}) async {
    await _jadwalkanHarian(
      id: idPengingatPulang,
      judul: '🏠 Pengingat Absen Pulang',
      isi: 'Jangan lupa absen pulang sebelum meninggalkan kantor!',
      jam: jam,
      menit: menit,
      channelId: _channelIdPresensi,
      channelName: 'Pengingat Presensi',
      payload: 'absen_pulang',
    );
  }

  // ─── Notifikasi Alpa ─────────────────────────────────────────────────────────

  /// Jadwalkan WARNING "Belum Absen" — muncul 1 jam setelah jam masuk shift,
  /// jika pegawai belum clock in. Diatur ulang setiap hari.
  ///
  /// Contoh: shift masuk 07:00 → peringatan muncul jam 08:00.
  Future<void> jadwalkanPeringatanBelumAbsen({
    required int jamMasuk,
    required int menitMasuk,
    int toleransiMenit = 60, // default 1 jam toleransi
  }) async {
    // Hitung jam peringatan = jam masuk + toleransi
    final totalMenit = jamMasuk * 60 + menitMasuk + toleransiMenit;
    final jamPeringatan = totalMenit ~/ 60;
    final menitPeringatan = totalMenit % 60;

    await _jadwalkanHarian(
      id: idPeringatanAlpa,
      judul: '⚠️ Kamu Belum Absen!',
      isi: 'Shift sudah dimulai tapi kamu belum clock in. '
          'Segera absen atau akan dicatat sebagai Alpa!',
      jam: jamPeringatan,
      menit: menitPeringatan,
      channelId: _channelIdPresensi,
      channelName: 'Pengingat Presensi',
      payload: 'peringatan_alpa',
    );
  }

  /// Jadwalkan notifikasi KONFIRMASI ALPA — muncul saat jam pulang shift berlalu
  /// dan pegawai tidak pernah clock in. Ini notifikasi one-shot (hanya hari ini).
  ///
  /// Berbeda dengan notifikasi harian, ini dijadwalkan sekali untuk jam spesifik
  /// hari ini (atau esok jika sudah lewat). Backend yang akan benar-benar
  /// menyimpan status Alpa ke database.
  Future<void> jadwalkanKonfirmasiAlpa({
    required int jamPulang,
    required int menitPulang,
  }) async {
    // Tambah 5 menit setelah jam pulang (beri waktu backend proses)
    final totalMenit = jamPulang * 60 + menitPulang + 5;
    final jamKonfirmasi = totalMenit ~/ 60;
    final menitKonfirmasi = totalMenit % 60;

    await _jadwalkanSekali(
      id: idKonfirmasiAlpa,
      judul: '🚨 Status Alpa Tercatat',
      isi: 'Kamu tidak absen pada shift hari ini. '
          'Kehadiranmu dicatat sebagai Alpa.',
      jam: jamKonfirmasi,
      menit: menitKonfirmasi,
      channelId: _channelIdPresensi,
      channelName: 'Pengingat Presensi',
      payload: 'konfirmasi_alpa',
    );
  }

  /// Batalkan notifikasi alpa untuk tanggal tertentu (default hari ini)
  Future<void> batalkanNotifikasiAlpaDinamis({DateTime? tanggal}) async {
    final tgl = tanggal ?? DateTime.now();
    final idMasuk = (tgl.year * 10000 + tgl.month * 100 + tgl.day) * 2;
    final idPulang = idMasuk + 1;

    await batalkan(idMasuk + 100000); // Peringatan alpa
    await batalkan(idPulang + 200000); // Konfirmasi alpa
  }

  /// Batalkan notifikasi peringatan & konfirmasi alpa (dipanggil saat clock in berhasil).
  Future<void> batalkanNotifikasiAlpa() async {
    await batalkan(idPeringatanAlpa);
    await batalkan(idKonfirmasiAlpa);
    await batalkanNotifikasiAlpaDinamis();
  }

  /// Membatalkan seluruh notifikasi presensi terjadwal secara surgical
  /// untuk rentang tanggal tertentu (default: hari ini hingga 14 hari ke depan).
  /// Ini menggantikan batalkanSemua() agar tidak menghapus notifikasi penting lainnya (seperti persetujuan cuti).
  Future<void> batalkanNotifikasiPresensiMendatang({int rentangHari = 14}) async {
    try {
      final now = DateTime.now();
      for (int i = 0; i <= rentangHari; i++) {
        final tgl = now.add(Duration(days: i));
        final idMasuk = (tgl.year * 10000 + tgl.month * 100 + tgl.day) * 2;
        final idPulang = idMasuk + 1;

        await batalkan(idMasuk);             // Pengingat masuk dinamis
        await batalkan(idMasuk + 100000);    // Peringatan alpa dinamis
        await batalkan(idPulang);            // Pengingat pulang dinamis
        await batalkan(idPulang + 200000);   // Konfirmasi alpa dinamis
      }
      if (kDebugMode) {
        print('Surgically cancelled upcoming presensi notifications for the next $rentangHari days.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error surgical cancel of upcoming presensi notifications: $e');
      }
    }
  }

  /// Membersihkan notifikasi presensi terjadwal yang sudah lampau (kedaluwarsa).
  /// Ini membantu menghapus notifikasi presensi lama yang telah lewat dari status bar Android
  /// dan membersihkan resource alarm.
  Future<void> bersihkanNotifikasiKedaluwarsa({int rentangHariLampau = 14}) async {
    try {
      final now = DateTime.now();
      for (int i = 1; i <= rentangHariLampau; i++) {
        final tgl = now.subtract(Duration(days: i));
        final idMasuk = (tgl.year * 10000 + tgl.month * 100 + tgl.day) * 2;
        final idPulang = idMasuk + 1;

        await batalkan(idMasuk);             // Pengingat masuk dinamis
        await batalkan(idMasuk + 100000);    // Peringatan alpa dinamis
        await batalkan(idPulang);            // Pengingat pulang dinamis
        await batalkan(idPulang + 200000);   // Konfirmasi alpa dinamis
      }

      // Bersihkan notifikasi alarm statis dari versi terdahulu jika ada
      await batalkan(idPengingatMasuk);
      await batalkan(idPengingatPulang);
      await batalkan(idPeringatanAlpa);
      await batalkan(idKonfirmasiAlpa);

      if (kDebugMode) {
        print('Surgically cleaned up expired/past presensi notifications for the last $rentangHariLampau days.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error surgical cleanup of expired presensi notifications: $e');
      }
    }
  }

  /// Jadwalkan notifikasi ONE-SHOT (sekali saja) pada tanggal dan waktu tertentu.
  Future<void> jadwalkanSekaliSpesifik({
    required int id,
    required String judul,
    required String isi,
    required DateTime waktu,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    final detail = NotificationDetails(
      android: _androidDetail(
        channelId: channelId,
        channelName: channelName,
        channelDescription: 'Pengingat presensi terjadwal',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // Konversi DateTime ke TZDateTime di timezone lokal
    final tzWaktu = tz.TZDateTime.from(waktu, tz.local);

    // Jangan jadwalkan jika waktu sudah berlalu
    if (tzWaktu.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      judul,
      isi,
      tzWaktu,
      detail,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Internal: jadwalkan notifikasi ONE-SHOT (tidak berulang) untuk jam tertentu hari ini.
  /// Jika jam sudah lewat hari ini, jadwalkan untuk besok.
  Future<void> _jadwalkanSekali({
    required int id,
    required String judul,
    required String isi,
    required int jam,
    required int menit,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    final detail = NotificationDetails(
      android: _androidDetail(
        channelId: channelId,
        channelName: channelName,
        channelDescription: 'Status kehadiran otomatis',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      judul,
      isi,
      _waktuBerikutnya(jam, menit),
      detail,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Tidak ada matchDateTimeComponents → hanya sekali, tidak berulang
      payload: payload,
    );
  }

  /// Internal: jadwalkan notifikasi berulang setiap hari pada [jam]:[menit].
  Future<void> _jadwalkanHarian({
    required int id,
    required String judul,
    required String isi,
    required int jam,
    required int menit,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    final detail = NotificationDetails(
      android: _androidDetail(
        channelId: channelId,
        channelName: channelName,
        channelDescription: 'Pengingat presensi harian',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      judul,
      isi,
      _waktuBerikutnya(jam, menit),
      detail,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // ulangi setiap hari
      payload: payload,
    );
  }

  /// Hitung [TZDateTime] berikutnya untuk jam:menit tertentu.
  /// Jika waktu hari ini sudah lewat, jadwalkan untuk besok.
  tz.TZDateTime _waktuBerikutnya(int jam, int menit) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      jam,
      menit,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ─── 3. Batalkan Notifikasi ───────────────────────────────────────────────────

  /// Batalkan satu notifikasi berdasarkan ID.
  Future<void> batalkan(int id) => _plugin.cancel(id);

  /// Batalkan semua notifikasi terjadwal maupun pending.
  Future<void> batalkanSemua() => _plugin.cancelAll();

  // ─── 4. Helper: cek notifikasi yang sedang aktif ─────────────────────────────

  Future<List<PendingNotificationRequest>> lihatPending() =>
      _plugin.pendingNotificationRequests();

  // ─── 5. Internal: Kirim laporan Alpa ke backend ──────────────────────────────

  /// Kirim laporan alpa ke backend Laravel.
  /// Dipanggil otomatis saat user tap notifikasi konfirmasi alpa.
  void _kirimLaporanAlpa() {
    // Fire-and-forget — tidak perlu await
    ApiService.instance.laporAlpa();
  }

  // ─── 6. Cek Perubahan Status Cuti/Izin/Sakit ────────────────────────────────
  
  /// Memeriksa perubahan status pengajuan cuti/izin/sakit dari server
  /// dan memicu notifikasi jika status disetujui (Approved) atau ditolak (Rejected).
  Future<void> periksaPerubahanStatusCuti() async {
    try {
      final List<CutiRecord> cutiList = await ApiService.instance.getCutiList(
        bulan: DateTime.now().month,
        tahun: DateTime.now().year,
      );

      final prefs = await SharedPreferences.getInstance();
      const String keyPrefix = 'cuti_status_';

      for (final cuti in cutiList) {
        if (cuti.batchId == null) continue;
        final String storageKey = '$keyPrefix${cuti.batchId}';

        // Ambil status sebelumnya
        final String? statusSebelumnya = prefs.getString(storageKey);
        final String statusSekarang = cuti.approvalStatus; // 'Pending', 'Approved', 'Rejected'

        // Update status terbaru ke storage
        await prefs.setString(storageKey, statusSekarang);

        // Jika sebelumnya belum ada record di local, tandai saja dan lanjut
        if (statusSebelumnya == null) {
          continue;
        }

        // Jika status berubah dari 'Pending' menjadi 'Approved' atau 'Rejected'
        if (statusSebelumnya == 'Pending' && statusSekarang != 'Pending') {
          final String jenisText = cuti.jenis; // 'Cuti', 'Izin', 'Sakit'
          final String tanggalText = cuti.tanggalMulai == cuti.tanggalSelesai
              ? cuti.tanggalMulai
              : '${cuti.tanggalMulai} s/d ${cuti.tanggalSelesai}';

          if (statusSekarang == 'Approved') {
            await tampilkanNotifikasi(
              id: cuti.batchId.hashCode, // Gunakan hashCode dari UUID sebagai notification id unik
              judul: '✅ Pengajuan $jenisText Disetujui!',
              isi: 'Pengajuan $jenisText Anda untuk tanggal $tanggalText telah DISETUJUI oleh Admin.',
              payload: 'cuti_approved',
            );
          } else if (statusSekarang == 'Rejected') {
            await tampilkanNotifikasi(
              id: cuti.batchId.hashCode,
              judul: '❌ Pengajuan $jenisText Ditolak',
              isi: 'Pengajuan $jenisText Anda untuk tanggal $tanggalText telah DITOLAK oleh Admin.',
              payload: 'cuti_rejected',
            );
          }
        }
      }
    } catch (_) {
      // Abaikan jika network error atau gagal ambil data
    }
  }
}
