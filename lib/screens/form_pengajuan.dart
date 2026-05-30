import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:get/get.dart';

const Map<String, String> kJenisLabels = {
  'Cuti': 'Cuti Tahunan',
  'Izin': 'Izin',
  'Sakit': 'Sakit',
};

class form_pengajuan extends StatefulWidget {
  const form_pengajuan({super.key});

  @override
  State<form_pengajuan> createState() => _form_pengajuanState();
}

class _form_pengajuanState extends State<form_pengajuan> {
  final _formKey = GlobalKey<FormState>();
  String _selectedJenis = 'Cuti';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  // Image picker state
  File? _medicalLetter;
  final ImagePicker _picker = ImagePicker();

  // Quota state
  Map<String, dynamic>? _quota;
  bool _isLoadingQuota = false;

  // Existing leaves state
  List<CutiRecord> _existingLeaves = [];
  bool _isLoadingLeaves = false;

  @override
  void initState() {
    super.initState();
    _fetchQuota();
    _fetchExistingLeaves();
  }

  Future<void> _fetchQuota() async {
    setState(() => _isLoadingQuota = true);
    try {
      final quota = await ApiService.instance.getCutiQuota();
      setState(() => _quota = quota);
    } catch (e) {
      debugPrint('Error fetching quota: $e');
    } finally {
      setState(() => _isLoadingQuota = false);
    }
  }

  Future<void> _fetchExistingLeaves() async {
    setState(() => _isLoadingLeaves = true);
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final currentList = await ApiService.instance.getCutiList(bulan: currentMonth, tahun: currentYear);

      final next = now.add(const Duration(days: 30));
      final nextList = await ApiService.instance.getCutiList(bulan: next.month, tahun: next.year);

      final prev = now.subtract(const Duration(days: 30));
      final prevList = await ApiService.instance.getCutiList(bulan: prev.month, tahun: prev.year);

      final all = [...currentList, ...nextList, ...prevList];
      final Map<String, CutiRecord> unique = {};
      for (var item in all) {
        if (item.batchId != null) {
          unique[item.batchId!] = item;
        }
      }

      setState(() {
        _existingLeaves = unique.values
            .where((c) => c.approvalStatus.toLowerCase() == 'pending' || c.approvalStatus.toLowerCase() == 'approved')
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching existing leaves: $e');
    } finally {
      setState(() => _isLoadingLeaves = false);
    }
  }

  bool _isDayBooked(DateTime day) {
    final checkDate = DateTime(day.year, day.month, day.day);

    for (final cuti in _existingLeaves) {
      try {
        final start = DateTime.parse(cuti.tanggalMulai);
        final end = DateTime.parse(cuti.tanggalSelesai);

        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = DateTime(end.year, end.month, end.day);

        if ((checkDate.isAtSameMomentAs(startDate) || checkDate.isAfter(startDate)) &&
            (checkDate.isAtSameMomentAs(endDate) || checkDate.isBefore(endDate))) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  DateTime _findFirstAvailableDate(DateTime startSearch) {
    var candidate = DateTime(startSearch.year, startSearch.month, startSearch.day);
    while (_isDayBooked(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _medicalLetter = File(image.path));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime initial;
    DateTime first;

    if (isStart) {
      first = today;
      final firstAvailable = _findFirstAvailableDate(today);
      initial = _startDate ?? firstAvailable;
      if (initial.isBefore(firstAvailable)) initial = firstAvailable;
    } else {
      first = _startDate ?? today;
      final firstAvailable = _findFirstAvailableDate(first);
      initial = _endDate ?? firstAvailable;
      if (initial.isBefore(firstAvailable)) initial = firstAvailable;
    }

    // Pastikan initialDate memuaskan predicate (tidak dibooking)
    initial = _findFirstAvailableDate(initial);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2101),
      selectableDayPredicate: (day) {
        // Hari yang sudah ada pengajuan (Pending / Approved) tidak bisa dipilih
        return !_isDayBooked(day);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      Get.snackbar('Peringatan', 'Pilih tanggal mulai dan selesai',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (_selectedJenis == 'Sakit' && _medicalLetter == null) {
      Get.snackbar('Peringatan', 'Pengajuan sakit wajib melampirkan foto surat dokter',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (_selectedJenis == 'Izin' && _medicalLetter == null) {
      Get.snackbar('Peringatan', 'Pengajuan izin wajib melampirkan foto bukti',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    // Validasi overlap dengan cuti yang sudah ada (Pending atau Approved)
    DateTime check = _startDate!;
    while (check.isBefore(_endDate!) || check.isAtSameMomentAs(_endDate!)) {
      if (_isDayBooked(check)) {
        final formattedDate = DateFormat('dd MMM yyyy', 'id').format(check);
        Get.snackbar(
          'Peringatan',
          'Tanggal $formattedDate sudah memiliki pengajuan aktif (Pending/Approved).',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
      check = check.add(const Duration(days: 1));
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.instance.submitCuti(
        jenis: _selectedJenis,
        tanggalMulai: _startDate!,
        tanggalSelesai: _endDate!,
        keterangan: _reasonController.text.trim(),
        suratDokterPath: _medicalLetter?.path,
      );

      if (!mounted) return;

      String pesan = result['message'] as String? ?? 'Pengajuan berhasil dikirim.';
      Get.back(result: pesan);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // 1. Jenis Pengajuan
                  _buildSection(
                    icon: Icons.category_outlined,
                    title: 'Jenis Pengajuan',
                    child: _buildJenisPicker(),
                  ),

                  // 2. Info Jatah Cuti
                  if (_selectedJenis == 'Cuti') ...[
                    const SizedBox(height: 12),
                    _buildQuotaCard(),
                  ],

                  const SizedBox(height: 12),

                  // 3. Tanggal
                  _buildSection(
                    icon: Icons.date_range,
                    title: 'Periode',
                    child: _buildDatePicker(),
                  ),

                  // 4. Upload Bukti
                  if (_selectedJenis == 'Sakit' || _selectedJenis == 'Izin') ...[
                    const SizedBox(height: 12),
                    _buildSection(
                      icon: Icons.camera_alt_outlined,
                      title: _selectedJenis == 'Sakit'
                          ? 'Foto Surat Dokter (Wajib)'
                          : 'Foto Bukti / Lampiran (Wajib)',
                      child: _buildImagePicker(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 5. Alasan
                  _buildSection(
                    icon: Icons.notes_outlined,
                    title: 'Alasan / Keterangan',
                    child: _buildReasonField(),
                  ),

                  const SizedBox(height: 24),

                  // 6. Submit
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 52, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buat Pengajuan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Isi formulir pengajuan di bawah',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildJenisPicker() {
    return Row(
      children: kJenisLabels.entries.map((entry) {
        final selected = _selectedJenis == entry.key;
        final color = _jenisColor(entry.key);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedJenis = entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _jenisIcon(entry.key),
                    size: 20,
                    color: selected ? Colors.white : Colors.grey.shade500,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuotaCard() {
    if (_isLoadingQuota) {
      return Container(
        height: 4,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
        child: const LinearProgressIndicator(
          backgroundColor: Color(0xFFE8EEF9),
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
        ),
      );
    }
    if (_quota == null) return const SizedBox();

    final total = _quota!['total'] as int? ?? 0;
    final terpakai = _quota!['terpakai'] as int? ?? 0;
    final sisa = _quota!['sisa'] as int? ?? 0;
    final pct = total > 0 ? (sisa / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 6),
              const Text(
                'Jatah Cuti Tahunan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuotaItem('Total', '$total hari', Colors.grey.shade600),
              const SizedBox(width: 12),
              _buildQuotaItem('Terpakai', '$terpakai hari', const Color(0xFFF57C00)),
              const SizedBox(width: 12),
              _buildQuotaItem('Sisa', '$sisa hari', const Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        Expanded(child: _buildDateButton('Tanggal Mulai', _startDate, () => _selectDate(context, true))),
        const SizedBox(width: 10),
        Expanded(child: _buildDateButton('Tanggal Selesai', _endDate, _startDate == null ? null : () => _selectDate(context, false))),
      ],
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback? onTap) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFF1E3A8A).withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasDate ? const Color(0xFF1E3A8A).withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: hasDate ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  Text(
                    hasDate
                        ? DateFormat('dd MMM yyyy', 'id').format(date!)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                      color: hasDate ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
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

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _medicalLetter != null
              ? Colors.transparent
              : const Color(0xFF1E3A8A).withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _medicalLetter != null
                ? const Color(0xFF2E7D32).withOpacity(0.4)
                : const Color(0xFF1E3A8A).withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: _medicalLetter != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(
                      _medicalLetter!,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Overlay buttons
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Row(
                      children: [
                        _overlayButton(
                          icon: Icons.camera_alt,
                          label: 'Ulangi',
                          onTap: _pickImage,
                          color: const Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 6),
                        _overlayButton(
                          icon: Icons.delete_outline,
                          label: 'Hapus',
                          onTap: () => setState(() => _medicalLetter = null),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ambil Foto Sekarang',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Foto langsung dari kamera',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _overlayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      decoration: InputDecoration(
        hintText: 'Tulis alasan atau keterangan...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.all(12),
      ),
      maxLines: 4,
      maxLength: 500,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Alasan tidak boleh kosong';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Kirim Pengajuan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
