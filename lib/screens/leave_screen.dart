import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'leave_form_screen.dart';

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
    // Assign langsung tanpa setState di initState
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

  void _refresh() {
    _loadData();
  }

  Color _statusColor(String approvalStatus) {
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
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

  IconData _jenisIcon(String jenis) {
    switch (jenis) {
      case 'Sakit':
        return Icons.local_hospital;
      case 'Izin':
        return Icons.assignment;
      default:
        return Icons.flight_takeoff; // Cuti
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Cuti / Izin'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
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
                      padding: const EdgeInsets.all(32.0),
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
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
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
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada pengajuan di bulan\n${_months[_selectedMonth - 1]} $_selectedYear',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: requests.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(
                          milliseconds: 300 + (index * 50).clamp(0, 500)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _showLeaveDetails(context, req),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3A8A)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _jenisIcon(req.jenis),
                                            color: const Color(0xFF1E3A8A),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _jenisLabel(req.jenis),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(req.approvalStatus),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.date_range,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            req.durasi > 1
                                                ? '${DateFormat('dd MMM', 'id').format(DateTime.parse(req.tanggalMulai))} - ${DateFormat('dd MMM yyyy', 'id').format(DateTime.parse(req.tanggalSelesai))}'
                                                : DateFormat('dd MMM yyyy', 'id')
                                                    .format(DateTime.parse(
                                                        req.tanggalMulai)),
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          '${req.durasi} Hari',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (req.keterangan != null &&
                                    req.keterangan!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    req.keterangan!,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      req.createdAt != null
                                          ? 'Diajukan: ${DateFormat('dd MMM yyyy', 'id').format(req.createdAt!)}'
                                          : 'Diajukan: -',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        size: 16, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
          final shouldRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (context) => const LeaveFormScreen()),
          );
          if (shouldRefresh == true) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajukan'),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                items: List.generate(12, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text(_months[index]),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                items: _years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedYear = value;
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String approvalStatus) {
    final color = _statusColor(approvalStatus);
    final label = _statusLabel(approvalStatus);

    IconData icon;
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        icon = Icons.check_circle;
        break;
      case 'rejected':
        icon = Icons.cancel;
        break;
      default:
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showLeaveDetails(BuildContext context, CutiRecord req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final color = _statusColor(req.approvalStatus);
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).padding.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_jenisIcon(req.jenis),
                        color: const Color(0xFF1E3A8A), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detail Pengajuan',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        if (req.createdAt != null)
                          Text(
                            'Diajukan pada ${DateFormat('dd MMM yyyy', 'id').format(req.createdAt!)}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _detailRow('Jenis', _jenisLabel(req.jenis)),
              const Divider(height: 24),
              _detailRow(
                'Tanggal',
                req.durasi > 1
                    ? '${DateFormat('dd MMM', 'id').format(DateTime.parse(req.tanggalMulai))} - ${DateFormat('dd MMM yyyy', 'id').format(DateTime.parse(req.tanggalSelesai))}'
                    : DateFormat('dd MMMM yyyy', 'id')
                        .format(DateTime.parse(req.tanggalMulai)),
              ),
              const Divider(height: 24),
              _detailRow('Durasi', '${req.durasi} Hari'),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text(
                    _statusLabel(req.approvalStatus),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ],
              ),
              if (req.keterangan != null && req.keterangan!.isNotEmpty) ...[
                const Divider(height: 24),
                const Text('Keterangan:',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(req.keterangan!,
                    style: const TextStyle(fontSize: 16)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
