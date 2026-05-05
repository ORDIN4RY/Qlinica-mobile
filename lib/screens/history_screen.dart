import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/attendance_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<int> _years = [
    DateTime.now().year - 1,
    DateTime.now().year,
    DateTime.now().year + 1
  ];

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Kehadiran'),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: AnimatedBuilder(
              animation: dataService,
              builder: (context, child) {
                final history = dataService.attendanceHistory.where((record) {
                  return record.date.month == _selectedMonth && record.date.year == _selectedYear;
                }).toList();
                
                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada riwayat kehadiran di bulan ${_months[_selectedMonth - 1]} $_selectedYear',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: history.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final record = history[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            _showAttendanceDetails(context, record);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle, color: Colors.green),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEEE, dd MMMM yyyy').format(record.date),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.login, size: 16, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(record.clockInTime != null 
                                              ? DateFormat('HH:mm').format(record.clockInTime!) 
                                              : '--:--'),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.logout, size: 16, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(record.clockOutTime != null 
                                              ? DateFormat('HH:mm').format(record.clockOutTime!) 
                                              : '--:--'),
                                        ],
                                      ),
                                    ],
                                  ),
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
          const Icon(Icons.calendar_month, color: Colors.blue),
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
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDetails(BuildContext context, AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Kehadiran',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(record.date),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                icon: Icons.login,
                color: Colors.blue,
                label: 'Waktu Masuk',
                value: record.clockInTime != null ? DateFormat('HH:mm').format(record.clockInTime!) : '--:--',
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.logout,
                color: Colors.orange,
                label: 'Waktu Keluar',
                value: record.clockOutTime != null ? DateFormat('HH:mm').format(record.clockOutTime!) : '--:--',
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.location_on,
                color: Colors.red,
                label: 'Lokasi',
                value: record.isLocationValid == true ? 'Sesuai Jarak Kantor' : (record.clockInTime != null ? 'Tidak tercatat / Luar jangkauan' : '-'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({required IconData icon, required Color color, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
