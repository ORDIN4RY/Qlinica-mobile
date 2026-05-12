import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_request.dart';
import '../services/data_service.dart';
import 'leave_form_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
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
        title: const Text('Pengajuan Cuti / Izin'),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: AnimatedBuilder(
              animation: dataService,
              builder: (context, child) {
                final requests = dataService.leaveRequests.where((req) {
                  return req.createdAt.month == _selectedMonth && req.createdAt.year == _selectedYear;
                }).toList();

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada pengajuan di bulan ${_months[_selectedMonth - 1]} $_selectedYear',
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
                            _showLeaveDetails(context, req);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            req.type == LeaveType.sick ? Icons.local_hospital : 
                                            (req.type == LeaveType.annual ? Icons.flight_takeoff : Icons.assignment),
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          req.type.label,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(req.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('dd MMM yyyy', 'id').format(req.startDate)} - ${DateFormat('dd MMM yyyy', 'id').format(req.endDate)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  req.reason,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Diajukan: ${DateFormat('dd MMM yyyy HH:mm', 'id').format(req.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                  ],
                                )
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveFormScreen()),
          );
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

  Widget _buildStatusBadge(LeaveStatus status) {
    Color color;
    switch (status) {
      case LeaveStatus.pending:
        color = Colors.orange;
        break;
      case LeaveStatus.approved:
        color = Colors.green;
        break;
      case LeaveStatus.rejected:
        color = Colors.red;
        break;
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
          Icon(
            status == LeaveStatus.approved ? Icons.check_circle :
            (status == LeaveStatus.rejected ? Icons.cancel : Icons.pending),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showLeaveDetails(BuildContext context, LeaveRequest req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0, right: 24.0, top: 24.0,
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      req.type == LeaveType.sick ? Icons.local_hospital : 
                      (req.type == LeaveType.annual ? Icons.flight_takeoff : Icons.assignment),
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Pengajuan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Diajukan pada ${DateFormat('dd MMM yyyy HH:mm', 'id').format(req.createdAt)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(label: 'Jenis', value: req.type.label),
              const Divider(height: 24),
              _buildDetailRow(label: 'Status', value: req.status.label, isStatus: true, status: req.status),
              const Divider(height: 24),
              _buildDetailRow(label: 'Mulai', value: DateFormat('dd MMMM yyyy', 'id').format(req.startDate)),
              const Divider(height: 24),
              _buildDetailRow(label: 'Sampai', value: DateFormat('dd MMMM yyyy', 'id').format(req.endDate)),
              const Divider(height: 24),
              const Text('Alasan:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(req.reason, style: const TextStyle(fontSize: 16)),
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

  Widget _buildDetailRow({required String label, required String value, bool isStatus = false, LeaveStatus? status}) {
    Color? valueColor;
    if (isStatus && status != null) {
      switch (status) {
        case LeaveStatus.pending: valueColor = Colors.orange; break;
        case LeaveStatus.approved: valueColor = Colors.green; break;
        case LeaveStatus.rejected: valueColor = Colors.red; break;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isStatus ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
