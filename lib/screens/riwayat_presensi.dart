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
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Gagal memuat data.\n${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                final records = (data['presensi'] as List<PresensiRecord>);
                final ringkasan = data['ringkasan'] as Map<String, dynamic>?;

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada data kehadiran\ndi ${_months[_selectedMonth - 1]} $_selectedYear',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Ringkasan bulanan
                    if (ringkasan != null) _buildRingkasan(ringkasan),
                    const SizedBox(height: 16),
                    // Daftar presensi
                    ...records.asMap().entries.map((entry) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 200 + (entry.key * 40).clamp(0, 400)),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Color(0xFF1E3A8A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontWeight: FontWeight.w500,
                ),
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
          Container(width: 1, height: 28, color: Colors.grey.shade200),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                  fontWeight: FontWeight.w500,
                ),
                items: _years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(y.toString()),
                )).toList(),
                onChanged: (v) {
                  if (v != null) { setState(() => _selectedYear = v); _loadData(); }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingkasan(Map<String, dynamic> ringkasan) {
    final hadir = ringkasan['hadir'] as int? ?? 0;
    final telat = ringkasan['telat'] as int? ?? 0;
    final alpha = ringkasan['alpha'] as int? ?? 0;
    final cuti = ringkasan['cuti'] as int? ?? 0;
    final izin = ringkasan['izin'] as int? ?? 0;
    final sakit = ringkasan['sakit'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan ${_months[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryChip('Hadir', hadir, const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _buildSummaryChip('Telat', telat, const Color(0xFFF57C00)),
                const SizedBox(width: 8),
                _buildSummaryChip('Cuti', cuti, const Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                _buildSummaryChip('Izin', izin, const Color(0xFF0288D1)),
                const SizedBox(width: 8),
                _buildSummaryChip('Sakit', sakit, const Color(0xFF00838F)),
                const SizedBox(width: 8),
                _buildSummaryChip('Alpha', alpha, const Color(0xFFE53935)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(PresensiRecord record) {
    final statusColor = _statusColor(record);
    final statusIcon = _statusIcon(record);
    final statusLabel = _statusLabel(record);
    final isAlpha = record.status == 'Alpha';
    final isLibur = record.status == 'Libur';
    final isLate = !isAlpha && !isLibur && record.telatMenit > 0;
    final isNonHadir = ['Cuti', 'Izin', 'Sakit'].contains(record.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isLibur ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlpha
              ? const Color(0xFFE53935).withValues(alpha: 0.3)
              : isLate
                  ? const Color(0xFFF57C00).withValues(alpha: 0.2)
                  : Colors.transparent,
        ),
        boxShadow: isLibur
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Info tengah
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tanggal
                  Text(
                    DateFormat('EEEE, dd MMM yyyy', 'id')
                        .format(DateTime.parse(record.tanggal)),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isLibur ? Colors.grey.shade500 : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (isAlpha)
                    Text(
                      'Tidak hadir • Tanpa keterangan',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    )
                  else if (isLibur)
                    Text(
                      'Hari libur sesuai jadwal shift',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                    )
                  else if (isNonHadir)
                    Text(
                      record.keterangan ?? record.status,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    )
                  else
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
                        _buildTimeChip(
                          Icons.logout,
                          record.jamKeluar != null
                              ? record.jamKeluar!.substring(0, 5)
                              : '--:--',
                          Colors.grey,
                        ),
                      ],
                    ),

                  if (isLate && record.keterangan != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      record.keterangan!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF57C00),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status badge
            if (!isLibur)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              )
            else
              Icon(Icons.beach_access, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
