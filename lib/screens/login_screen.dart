import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'main_navigation.dart';
import 'package:get/get.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _noRekamMedikController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final LocalAuthentication _auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      canCheckBiometrics = false;
    }

    final isBiometricEnabled = await ApiService.instance.isBiometricEnabled();
    final hasToken = await ApiService.instance.isLoggedIn;

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics =
          canCheckBiometrics && isBiometricEnabled && hasToken;
    });

    // Jika biometrik tersedia dan aktif, otomatis munculkan prompt
    if (_canCheckBiometrics) {
      // Delay sedikit agar animasi login screen selesai dulu
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() => _isLoading = true);
      authenticated = await _auth.authenticate(
        localizedReason: 'Pindai sidik jari Anda untuk login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Autentikasi biometrik dibatalkan/gagal.')),
      );
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      // Daftarkan FCM Token perangkat ke server Laravel
      FcmService.instance.getAndSendToken();
      Get.offAll(() => const MainNavigation());
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _noRekamMedikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await ApiService.instance.login(
        _noRekamMedikController.text.trim(), // email pegawai
        _passwordController.text,
      );

      await ApiService.instance.saveUser(user);

      if (_rememberMe) {
        try {
          final canCheck =
              await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
          if (canCheck) {
            await ApiService.instance.setBiometricEnabled(true);
          }
        } catch (_) {}
      } else {
        await ApiService.instance.setBiometricEnabled(false);
      }

      if (!mounted) return;

      // Daftarkan FCM Token perangkat ke server Laravel
      FcmService.instance.getAndSendToken();

      // Navigasi ke halaman utama, hapus semua route sebelumnya
      Get.offAll(() => const MainNavigation());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      Get.snackbar(
        'Gagal Login',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    }
  }

  void _onForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── Top branded header ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0D2461), Color(0xFF1E3A8A), Color(0xFF1565C0)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo row
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  image: const DecorationImage(
                                    image: AssetImage('assets/images/app_icon_blue.png'),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Qlinica',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Sistem Manajemen Klinik',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Selamat Datang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Silahkan masuk dengan akun pegawai Anda.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Form Card ──────────────────────────────────────────
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header baris dengan label + lupa password
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
                                                ),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Masuk Akun',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1A1A2E),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Email field
                                    _buildFieldLabel('Email Pegawai', Icons.email_outlined),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _noRekamMedikController,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF222222),
                                      ),
                                      decoration: _inputDecoration(
                                        'nama@klinisahaduta.com',
                                        prefixIcon: Icons.alternate_email,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Email tidak boleh kosong';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Password field
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildFieldLabel('Password', Icons.lock_outline_rounded),
                                        GestureDetector(
                                          onTap: _onForgotPassword,
                                          child: const Text(
                                            'Lupa Password?',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF1E3A8A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _onLogin(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF222222),
                                      ),
                                      decoration: _inputDecoration(
                                        '••••••••',
                                        prefixIcon: Icons.lock_outline_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFFAAAAAA),
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password tidak boleh kosong';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Ingat Saya
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: const Color(0xFF1E3A8A),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            onChanged: (val) => setState(
                                              () => _rememberMe = val ?? false,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Ingat saya',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: Color(0xFF444444),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Info text
                                    Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF1E3A8A).withOpacity(0.12),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            color: Color(0xFF2D6CDF),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Gunakan email dan password yang diberikan oleh admin klinik.',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF444466),
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Tombol Login
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _onLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E3A8A),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(0xFF1E3A8A).withOpacity(0.6),
                                          elevation: 3,
                                          shadowColor: const Color(0xFF1E3A8A).withOpacity(0.4),
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
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.login_rounded, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Masuk',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    if (_canCheckBiometrics) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : _authenticateWithBiometrics,
                                          icon: const Icon(
                                            Icons.fingerprint,
                                            size: 24,
                                          ),
                                          label: const Text(
                                            'Login dengan Biometrik',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF1E3A8A),
                                            side: const BorderSide(
                                              color: Color(0xFF1E3A8A),
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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

/// ── Bottom sheet Lupa Password ─────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    try {
      await ApiService.instance.forgotPassword(_emailCtrl.text.trim());
      
      if (!mounted) return;
      
      // Tutup bottom sheet
      Navigator.pop(context);
      
      // Buka halaman reset password
      Get.to(() => ResetPasswordScreen(email: _emailCtrl.text.trim()));
      
    } catch (e) {
      if (!mounted) return;
      
      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon header
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lupa Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Reset kata sandi Anda',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_sent) ...[
              // Success state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF22C55E),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Permintaan Terkirim!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Silahkan hubungi admin klinik untuk mendapatkan password baru ke email:\n${_emailCtrl.text.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Kembali ke Login',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              // Form state
              Text(
                'Masukkan email yang terdaftar pada akun Anda. Admin klinik akan mengirimkan instruksi reset password.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'nama@klinisahaduta.com',
                    hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                    labelText: 'Email Terdaftar',
                    labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Color(0xFFAAAAAA)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1E3A8A).withOpacity(0.6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Kirim Permintaan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
