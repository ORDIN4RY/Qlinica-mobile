import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchQuota();
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _medicalLetter = File(image.path));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan selesai')),
      );
      return;
    }

    if (_selectedJenis == 'Sakit' && _medicalLetter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan sakit wajib melampirkan surat dokter'),
        ),
      );
      return;
    }

    if (_selectedJenis == 'Izin' && _medicalLetter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan izin wajib melampirkan foto bukti'),
        ),
      );
      return;
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

      String pesan =
          result['message'] as String? ?? 'Pengajuan berhasil dikirim.';
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesan), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pengajuan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. Jenis Pengajuan — harus pertama
              DropdownButtonFormField<String>(
                value: _selectedJenis,
                decoration: const InputDecoration(
                  labelText: 'Jenis Pengajuan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: kJenisLabels.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedJenis = value);
                },
              ),

              // 2. Info Jatah Cuti — tampil di bawah dropdown jika Cuti
              if (_selectedJenis == 'Cuti') ...[
                const SizedBox(height: 12),
                _buildQuotaInfo(),
              ],

              const SizedBox(height: 16),

              // 3. Tanggal Mulai & Selesai
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Mulai',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat(
                                  'dd MMM yyyy',
                                  'id',
                                ).format(_startDate!)
                              : 'Pilih Tanggal',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _startDate == null
                          ? null
                          : () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tanggal Selesai',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          enabled: _startDate != null,
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat(
                                  'dd MMM yyyy',
                                  'id',
                                ).format(_endDate!)
                              : 'Pilih Tanggal',
                          style: TextStyle(
                            color: _startDate == null ? Colors.grey : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 4. Upload Bukti — Sakit atau Izin
              if (_selectedJenis == 'Sakit' || _selectedJenis == 'Izin') ...[
                const SizedBox(height: 16),
                _buildMedicalLetterPicker(),
              ],

              const SizedBox(height: 16),

              // 5. Alasan
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Keterangan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Alasan tidak boleh kosong';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // 6. Tombol Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kirim Pengajuan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaInfo() {
    if (_isLoadingQuota) {
      return const LinearProgressIndicator();
    }
    if (_quota == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9FB4D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Jatah Cuti Tahunan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ${_quota!["total"]} hari'),
              Text('Terpakai: ${_quota!["terpakai"]} hari'),
              Text(
                'Sisa: ${_quota!["sisa"]} hari',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalLetterPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedJenis == 'Sakit'
              ? 'Surat Dokter (Wajib)'
              : 'Foto Bukti / Lampiran (Wajib)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: _medicalLetter == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedJenis == 'Sakit'
                            ? 'Ambil Foto Surat Dokter'
                            : 'Ambil Foto Bukti Kejadian',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _medicalLetter!,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () =>
                                setState(() => _medicalLetter = null),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
