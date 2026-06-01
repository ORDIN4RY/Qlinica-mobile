import 'package:get/get.dart';
import '../services/api_service.dart';

class PresensiController extends GetxController {
  static PresensiController get to => Get.find();

  // Variabel reaktif (.obs)
  final hasClockedIn = false.obs;
  final hasClockedOut = false.obs;
  final isLoadingStatus = true.obs;

  final rxTodayRecord = Rxn<PresensiRecord>();
  final rxJadwalToday = Rxn<Map<String, dynamic>>();
  final rxUpcomingShifts = Rx<List<dynamic>>([]);

  /// Mengambil data status presensi hari ini dan jadwal dari server API
  Future<void> loadTodayStatus() async {
    try {
      isLoadingStatus.value = true;
      final data = await ApiService.instance.getPresensi(
        bulan: DateTime.now().month,
        tahun: DateTime.now().year,
      );

      hasClockedIn.value = data['has_clocked_in'] as bool? ?? false;
      hasClockedOut.value = data['has_clocked_out'] as bool? ?? false;
      rxTodayRecord.value = data['today'] as PresensiRecord?;
      
      Map<String, dynamic>? jadwalToday = data['jadwal_today'] as Map<String, dynamic>?;
      List<dynamic> upcoming = data['jadwal_upcoming'] as List<dynamic>? ?? [];

      try {
        final cutiList = await ApiService.instance.getCutiList(
          bulan: DateTime.now().month,
          tahun: DateTime.now().year,
        );
        final approvedCuti = cutiList.where((c) => c.approvalStatus.toLowerCase() == 'approved').toList();

        // 1. Filter upcoming shifts
        upcoming = upcoming.where((shift) {
          final tglStr = shift['tanggal']?.toString();
          if (tglStr == null) return true;
          final shiftDate = DateTime.parse(tglStr);

          for (final cuti in approvedCuti) {
            final start = DateTime.parse(cuti.tanggalMulai);
            final end = DateTime.parse(cuti.tanggalSelesai);
            final dateOnly = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
            final startOnly = DateTime(start.year, start.month, start.day);
            final endOnly = DateTime(end.year, end.month, end.day);

            if ((dateOnly.isAfter(startOnly) || dateOnly.isAtSameMomentAs(startOnly)) &&
                (dateOnly.isBefore(endOnly) || dateOnly.isAtSameMomentAs(endOnly))) {
              return false; // Exclude because of approved leave
            }
          }
          return true;
        }).toList();

        // 2. Filter jadwal_today
        if (jadwalToday != null) {
          final today = DateTime.now();
          for (final cuti in approvedCuti) {
            final start = DateTime.parse(cuti.tanggalMulai);
            final end = DateTime.parse(cuti.tanggalSelesai);
            final dateOnly = DateTime(today.year, today.month, today.day);
            final startOnly = DateTime(start.year, start.month, start.day);
            final endOnly = DateTime(end.year, end.month, end.day);

            if ((dateOnly.isAfter(startOnly) || dateOnly.isAtSameMomentAs(startOnly)) &&
                (dateOnly.isBefore(endOnly) || dateOnly.isAtSameMomentAs(endOnly))) {
              jadwalToday = {
                'nama': 'Libur (${cuti.jenis})',
                'masuk': '--:--',
                'pulang': '--:--',
              };
              break;
            }
          }
        }
      } catch (e) {
        // Jika gagal ambil cuti, biarkan jadwal apa adanya
      }

      rxJadwalToday.value = jadwalToday;
      rxUpcomingShifts.value = upcoming;
    } catch (_) {
      // Abaikan jika network error atau gagal ambil data, state lama tetap tersimpan
    } finally {
      isLoadingStatus.value = false;
    }
  }

  /// Memperbarui status Clock In/Out secara instan dari lokal (tanpa panggil API berulang)
  void setStatusPresensi({required bool masuk, required bool pulang}) {
    hasClockedIn.value = masuk;
    hasClockedOut.value = pulang;
  }
}
