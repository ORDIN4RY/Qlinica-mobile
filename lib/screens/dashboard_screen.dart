import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import 'attendance_process_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DataService _dataService = DataService();
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    
    // Add listener to data service to refresh UI when state changes
    _dataService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _timer.cancel();
    _dataService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sahaduta Attendance'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimeHeader(),
            const SizedBox(height: 32),
            _buildAttendanceStatus(),
            const SizedBox(height: 48),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeHeader() {
    return Column(
      children: [
        Text(
          DateFormat('HH:mm:ss').format(_currentTime),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, dd MMMM yyyy').format(_currentTime),
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatus() {
    final record = _dataService.todayRecord;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusColumn(
              'Masuk',
              record?.clockInTime != null 
                  ? DateFormat('HH:mm').format(record!.clockInTime!)
                  : '--:--',
              Icons.login,
              Colors.green,
            ),
            Container(width: 1, height: 50, color: Colors.grey.shade300),
            _buildStatusColumn(
              'Pulang',
              record?.clockOutTime != null 
                  ? DateFormat('HH:mm').format(record!.clockOutTime!)
                  : '--:--',
              Icons.logout,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusColumn(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons() {
    final hasClockedIn = _dataService.hasClockedIn;
    final hasClockedOut = _dataService.hasClockedOut;

    if (!hasClockedIn) {
      return ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AttendanceProcessScreen(isClockIn: true),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('CLOCK IN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    } else if (!hasClockedOut) {
      return ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AttendanceProcessScreen(isClockIn: false),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('CLOCK OUT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            'Kehadiran Hari Ini Selesai',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      );
    }
  }
}
