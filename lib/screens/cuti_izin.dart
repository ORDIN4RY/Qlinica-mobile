import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'form_pengajuan.dart';
import 'package:get/get.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  late Future<List<CutiRecord>> _future;

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
    _future = ApiService.instance.getCutiList(
      bulan: _selectedMonth,
      tahun: _selectedYear,
    );
  }

  void _loadData() {
    setState(() {
      _future = ApiService.instance.getCutiList(
        bulan: _selectedMonth,
        tahun: _selectedYear,
      );
    });
  }

  Color _statusColor(String approvalStatus) {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFF57C00);
    }
  }

  String _statusLabel(String approvalStatus) {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  IconData _statusIcon(String approvalStatus) {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  IconData _jenisIcon(String jenis) {
    switch (jenis) {
      case 'Sakit':
        return Icons.local_hospital_outlined;
      case 'Izin':
        return Icons.assignment_late_outlined;
      default:
        return Icons.flight_takeoff;
    }
  }

  String _jenisLabel(String jenis) {
    switch (jenis) {
      case 'Sakit':
        return 'Sakit';
      case 'Izin':
        return 'Izin';
      default:
        return 'Cuti Tahunan';
    }
  }

  Color _jenisColor(String jenis) {
    switch (jenis) {
      case 'Sakit':
        return const Color(0xFF00838F);
      case 'Izin':
        return const Color(0xFF0288D1);
      default:
        return const Color(0xFF1E3A8A);
    }
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
            child: FutureBuilder<List<CutiRecord>>(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
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

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada pengajuan di bulan',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                        Text(
                          '${_months[_selectedMonth - 1]} $_selectedYear',
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 400)),
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
                      child: _buildRequestCard(req),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.to<dynamic>(() => const form_pengajuan());
          if (result != null) {
            _loadData();
            String msg = 'Pengajuan berhasil dikirim.';
            if (result is String) {
              msg = result;
            }
            Get.snackbar(
              'Berhasil',
              msg,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
            );
          }
        },
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajukan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          const Icon(Icons.event_note, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pengajuan Cuti / Izin',
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
                            if (v != null) {
                              setState(() => _selectedMonth = v);
                              _loadData();
                            }
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
                        if (v != null) {
                          setState(() => _selectedYear = v);
                          _loadData();
                        }
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

  Widget _buildRequestCard(CutiRecord req) {
    final statusColor = _statusColor(req.approvalStatus);
    final jenisColor = _jenisColor(req.jenis);

    return GestureDetector(
      onTap: () => _showLeaveDetails(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: jenisColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_jenisIcon(req.jenis), color: jenisColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _jenisLabel(req.jenis),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (req.createdAt != null)
                          Text(
                            'Diajukan: ${DateFormat('dd MMM yyyy', 'id').format(req.createdAt!)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(req.approvalStatus), size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(req.approvalStatus),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 15, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req.durasi > 1
                            ? '${DateFormat('dd MMM', 'id').format(DateTime.parse(req.tanggalMulai))} – ${DateFormat('dd MMM yyyy', 'id').format(DateTime.parse(req.tanggalSelesai))}'
                            : DateFormat('dd MMMM yyyy', 'id').format(DateTime.parse(req.tanggalMulai)),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${req.durasi} Hari',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (req.keterangan != null && req.keterangan!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  req.keterangan!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lihat Detail',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1E3A8A).withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF1E3A8A)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveDetails(CutiRecord req) {
    final statusColor = _statusColor(req.approvalStatus);
    final jenisColor = _jenisColor(req.jenis);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 0,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: jenisColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_jenisIcon(req.jenis), color: jenisColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Pengajuan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (req.createdAt != null)
                          Text(
                            'Diajukan pada ${DateFormat('dd MMM yyyy', 'id').format(req.createdAt!)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Detail items
              _detailTile(Icons.category_outlined, 'Jenis', _jenisLabel(req.jenis), jenisColor),
              const SizedBox(height: 10),
              _detailTile(
                Icons.date_range,
                'Tanggal',
                req.durasi > 1
                    ? '${DateFormat('dd MMM', 'id').format(DateTime.parse(req.tanggalMulai))} – ${DateFormat('dd MMM yyyy', 'id').format(DateTime.parse(req.tanggalSelesai))}'
                    : DateFormat('dd MMMM yyyy', 'id').format(DateTime.parse(req.tanggalMulai)),
                const Color(0xFF1E3A8A),
              ),
              const SizedBox(height: 10),
              _detailTile(Icons.timer_outlined, 'Durasi', '${req.durasi} Hari', const Color(0xFF1565C0)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon(req.approvalStatus), color: statusColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        Text(
                          _statusLabel(req.approvalStatus),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (req.keterangan != null && req.keterangan!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keterangan', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(req.keterangan!, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withOpacity(0.8)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
            ],
          ),
        ],
      ),
    );
  }
}
