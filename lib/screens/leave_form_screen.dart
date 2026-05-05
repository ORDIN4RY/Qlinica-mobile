import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/leave_request.dart';
import '../services/data_service.dart';

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  LeaveType _selectedType = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih tanggal mulai dan selesai')),
        );
        return;
      }

      if (_endDate!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal selesai tidak boleh sebelum tanggal mulai')),
        );
        return;
      }

      final newRequest = LeaveRequest(
        id: Random().nextInt(10000).toString(),
        type: _selectedType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text,
        createdAt: DateTime.now(),
      );

      DataService().addLeaveRequest(newRequest);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dikirim')),
      );
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
      appBar: AppBar(
        title: const Text('Buat Pengajuan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<LeaveType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Pengajuan',
                  border: OutlineInputBorder(),
                ),
                items: LeaveType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Mulai',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat('dd MMM yyyy').format(_startDate!)
                              : 'Pilih Tanggal',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Selesai',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('dd MMM yyyy').format(_endDate!)
                              : 'Pilih Tanggal',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alasan tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Kirim Pengajuan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
