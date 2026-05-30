import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isOtpVerified = false; // <-- Menyimpan status OTP

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Memanggil endpoint baru /verify-otp
      await ApiService.instance.verifyOtp(
        widget.email,
        _otpController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isOtpVerified = true;
      });

      Get.snackbar(
        'Berhasil',
        'OTP Valid. Silakan masukkan password baru Anda.',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.instance.resetPassword(
        widget.email,
        _otpController.text.trim(),
        _newPasswordController.text,
      );

      if (!mounted) return;

      Get.snackbar(
        'Sukses',
        'Password berhasil direset. Silahkan login menggunakan password baru Anda.',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
      );

      Get.offAll(() => const LoginScreen());
    } catch (e) {
      if (!mounted) return;

      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2461),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Jika sudah verify OTP dan mau kembali, kembalikan ke state input OTP
              if (_isOtpVerified) {
                setState(() => _isOtpVerified = false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOtpVerified ? 'Buat Password Baru' : 'Masukkan Kode OTP',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpVerified
                        ? 'Silakan masukkan password baru untuk akun Anda.'
                        : 'Kami telah mengirimkan kode OTP ke email ${widget.email}. Masukkan kode tersebut untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!_isOtpVerified) ...[
                    // OTP Field
                    _buildFieldLabel('Kode OTP', Icons.security_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: _inputDecoration(
                        'Contoh: 123456',
                        prefixIcon: Icons.pin,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'OTP tidak boleh kosong';
                        }
                        if (val.trim().length < 6) {
                          return 'OTP minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    // New Password Field
                    _buildFieldLabel('Password Baru', Icons.lock_outline_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: _inputDecoration(
                        'Minimal 8 karakter',
                        prefixIcon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFAAAAAA),
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Password baru tidak boleh kosong';
                        }
                        if (val.length < 8) return 'Password minimal 8 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Confirm Password Field
                    _buildFieldLabel(
                      'Konfirmasi Password Baru',
                      Icons.lock_reset_rounded,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: _inputDecoration(
                        'Ulangi password baru',
                        prefixIcon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFAAAAAA),
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Konfirmasi password tidak boleh kosong';
                        }
                        if (val != _newPasswordController.text) {
                          return 'Password tidak cocok';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_isOtpVerified ? _onResetPassword : _verifyOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _isOtpVerified ? 'Reset Password' : 'Verifikasi OTP',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      counterText: "",
      hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: const Color(0xFFAAAAAA))
          : null,
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E4EC), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
      ),
    );
  }
}
