import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  late Future<Map<String, dynamic>> _future;

  final List<int> _years = [
    DateTime.now().year - 1,
    DateTime.now().year,
    DateTime.now().year + 1,
  ];

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getPresensi(
      bulan: _selectedMonth,
      tahun: _selectedYear,
    );
  }

  void _loadData() {
    setState(() {
      _future = ApiService.instance.getPresensi(
        bulan: _selectedMonth,
        tahun: _selectedYear,
      );
    });
  }

  // ── Status helpers ──────────────────────────────────────

  String _statusLabel(PresensiRecord r) {
    if (r.status == 'Terjadwal') return 'Terjadwal';
    if (r.status == 'Alpha' || r.status == 'Alpa') return 'Alpa';
    if (r.status == 'Libur') return 'Libur';
    if (r.status == 'Cuti') return 'Cuti';
    if (r.status == 'Izin') return 'Izin';
    if (r.status == 'Sakit') return 'Sakit';
    if (r.telatMenit > 0) return 'Telat ${r.telatMenit} mnt';
    return 'Hadir';
  }

  Color _statusColor(PresensiRecord r) {
    if (r.status == 'Terjadwal') return const Color(0xFF1E88E5);
    if (r.status == 'Alpha' || r.status == 'Alpa') return const Color(0xFFE53935);
    if (r.status == 'Libur') return const Color(0xFF607D8B);
    if (r.status == 'Cuti') return const Color(0xFF7B1FA2);
    if (r.status == 'Izin') return const Color(0xFF0288D1);
    if (r.status == 'Sakit') return const Color(0xFF00838F);
    if (r.telatMenit > 0) return const Color(0xFFF57C00);
    return const Color(0xFF2E7D32);
  }

  IconData _statusIcon(PresensiRecord r) {
    if (r.status == 'Terjadwal') return Icons.event_note;
    if (r.status == 'Alpha' || r.status == 'Alpa') return Icons.cancel_outlined;
    if (r.status == 'Libur') return Icons.beach_access;
    if (r.status == 'Cuti') return Icons.event_busy;
    if (r.status == 'Izin') return Icons.assignment_late_outlined;
    if (r.status == 'Sakit') return Icons.local_hospital_outlined;
    if (r.telatMenit > 0) return Icons.schedule;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final data = snapshot.data!;
                final records = (data['presensi'] as List<PresensiRecord>);

                if (records.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt, size: 16, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 6),
                          Text(
                            'Detail Kehadiran (${records.length} hari)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...records.asMap().entries.map((entry) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(
                          milliseconds: 200 + (entry.key * 40).clamp(0, 400),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildRecordCard(entry.value),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header (TIDAK DIUBAH) ────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Riwayat Kehadiran',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ──────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFFF4F6FB),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 13, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          isExpanded: true,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E3A8A)),
                          items: List.generate(12, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_months[i]),
                          )),
                          onChanged: (v) {
                            if (v != null) { setState(() => _selectedMonth = v); _loadData(); }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 5),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w700,
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E3A8A)),
                      items: _years.map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y.toString()),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) { setState(() => _selectedYear = v); _loadData(); }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading State ───────────────────────────────────────
  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(5, (i) => _buildSkeletonCard(i)),
    );
  }

  Widget _buildSkeletonCard(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: Duration(milliseconds: 900 + index * 100),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 26,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Error State ─────────────────────────────────────────
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 52, color: Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum Ada Data Kehadiran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada record di ${_months[_selectedMonth - 1]} $_selectedYear',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }



  // ── Record Card ──────────────────────────────────────────
  Widget _buildRecordCard(PresensiRecord record) {
    final statusColor = _statusColor(record);
    final statusIcon  = _statusIcon(record);
    final statusLabel = _statusLabel(record);
    final isAlpha     = record.status == 'Alpha' || record.status == 'Alpa';
    final isLibur     = record.status == 'Libur';
    final isLate      = !isAlpha && !isLibur && record.telatMenit > 0;
    final isHadir     = !isAlpha && !isLibur &&
                        !['Cuti', 'Izin', 'Sakit', 'Terjadwal'].contains(record.status);
    final isNonHadir  = ['Cuti', 'Izin', 'Sakit'].contains(record.status);
    final isTerjadwal = record.status == 'Terjadwal';

    final parsedDate  = DateTime.parse(record.tanggal);
    final dayName     = DateFormat('EEEE', 'id').format(parsedDate);
    final dayNum      = DateFormat('dd', 'id').format(parsedDate);
    final monthYear   = DateFormat('MMM yyyy', 'id').format(parsedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isLibur ? const Color(0xFFF8F8F8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: isLibur ? Colors.transparent : statusColor,
            width: 3.5,
          ),
        ),
        boxShadow: isLibur
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date block
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isLibur
                    ? Colors.grey.shade200
                    : statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLibur ? Colors.grey.shade500 : statusColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    monthYear,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: isLibur ? Colors.grey.shade400 : statusColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Middle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isLibur
                          ? Colors.grey.shade500
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 5),

                  if (isLibur)
                    Row(
                      children: [
                        const Icon(Icons.beach_access, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Hari libur',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else if (isAlpha)
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Tidak hadir • Tanpa keterangan',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                        ),
                      ],
                    )
                  else if (isTerjadwal)
                    Row(
                      children: [
                        Icon(Icons.event_note, size: 13, color: Colors.blue.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Belum absen',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade400),
                        ),
                      ],
                    )
                  else if (isNonHadir)
                    Row(
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            record.keterangan ?? statusLabel,
                            style: TextStyle(fontSize: 12, color: statusColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else if (isHadir)
                    Row(
                      children: [
                        _buildTimeChip(
                          Icons.login,
                          record.jamMasuk != null
                              ? record.jamMasuk!.substring(0, 5)
                              : '--:--',
                          const Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        _buildTimeChip(
                          Icons.logout,
                          record.jamKeluar != null
                              ? record.jamKeluar!.substring(0, 5)
                              : '--:--',
                          record.jamKeluar != null ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                      ],
                    ),

                  if (isLate && record.keterangan != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 11, color: Colors.orange.shade600),
                        const SizedBox(width: 3),
                        Text(
                          record.keterangan!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status badge
            if (!isLibur)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
