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
      rxJadwalToday.value = data['jadwal_today'] as Map<String, dynamic>?;
      rxUpcomingShifts.value = data['jadwal_upcoming'] as List<dynamic>? ?? [];
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
