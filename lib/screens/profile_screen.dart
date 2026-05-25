import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'package:get/get.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;

  // Edit Profil
  bool _isEditing = false;
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  bool _isSavingProfile = false;

  // Change password
  final _passFormKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSavingPass = false;
  bool _showChangePass = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final saved = await ApiService.instance.getSavedUser();
    if (!mounted) return;
    setState(() {
      _user = saved;
      _isLoading = false;
      if (saved != null) {
        _nameCtrl.text = saved.pegawai?['nama'] as String? ?? saved.name;
        _phoneCtrl.text = saved.pegawai?['no_hp'] as String? ?? '';
        _addressCtrl.text = saved.pegawai?['alamat'] as String? ?? '';
      }
    });
    // Refresh from server in background
    try {
      final fresh = await ApiService.instance.getMe();
      await ApiService.instance.saveUser(fresh);
      if (mounted) {
        setState(() {
          _user = fresh;
          _nameCtrl.text = fresh.pegawai?['nama'] as String? ?? fresh.name;
          _phoneCtrl.text = fresh.pegawai?['no_hp'] as String? ?? '';
          _addressCtrl.text = fresh.pegawai?['alamat'] as String? ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _onSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _isSavingProfile = true);
    try {
      final updatedUser = await ApiService.instance.updateProfile(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        address: _addressCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _isSavingProfile = false;
        _isEditing = false;
      });
      Get.snackbar(
        'Berhasil',
        'Profil berhasil diperbarui!',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingProfile = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _onChangePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _isSavingPass = true);
    try {
      await ApiService.instance.changePassword(
        _oldPassCtrl.text,
        _newPassCtrl.text,
      );
      if (!mounted) return;
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() {
        _isSavingPass = false;
        _showChangePass = false;
      });
      Get.snackbar(
        'Berhasil',
        'Password berhasil diubah!',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPass = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ApiService.instance.logout();
    if (!mounted) return;
    Get.offAll(() => const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final name = _user?.pegawai?['nama'] as String? ?? _user?.name ?? 'Pegawai';
    final email = _user?.email ?? '-';
    final jabatan = _user?.pegawai?['jabatan'] as String? ?? '-';
    final nik = _user?.pegawai?['nik'] as String? ?? '-';

    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Premium Header ────────────────────────────────────
          _buildProfileHeader(name, jabatan, initials),

          // ── Body ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                _buildSectionLabel('Informasi Pegawai', Icons.person_pin_outlined, actions: [
                  if (!_isEditing)
                    _buildHeaderAction(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      onTap: () => setState(() => _isEditing = true),
                    )
                  else
                    Row(children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            if (_user != null) {
                              _nameCtrl.text = _user!.pegawai?['nama'] as String? ?? _user!.name;
                              _phoneCtrl.text = _user!.pegawai?['no_hp'] as String? ?? '';
                              _addressCtrl.text = _user!.pegawai?['alamat'] as String? ?? '';
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Batal', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _isSavingProfile ? null : _onSaveProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isSavingProfile
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Simpan', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                ]),
                const SizedBox(height: 12),

                // Info card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.badge_outlined, 'NIK', nik, const Color(0xFF1565C0), isFirst: true),
                      _buildDivider(),
                      _buildInfoRow(Icons.email_outlined, 'Email', email, const Color(0xFF0288D1)),
                      _buildDivider(),
                      _buildInfoRow(Icons.work_outline, 'Jabatan', jabatan, const Color(0xFF7B1FA2)),
                      _buildDivider(),
                      Form(
                        key: _profileFormKey,
                        child: Column(
                          children: [
                            _buildEditableRow(
                              icon: Icons.person_outline,
                              label: 'Nama',
                              iconColor: const Color(0xFF1E3A8A),
                              controller: _nameCtrl,
                              isEditing: _isEditing,
                              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                            ),
                            _buildDivider(),
                            _buildEditableRow(
                              icon: Icons.phone_outlined,
                              label: 'No. HP',
                              iconColor: const Color(0xFF2E7D32),
                              controller: _phoneCtrl,
                              isEditing: _isEditing,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildDivider(),
                            _buildEditableRow(
                              icon: Icons.location_on_outlined,
                              label: 'Alamat',
                              iconColor: const Color(0xFFE53935),
                              controller: _addressCtrl,
                              isEditing: _isEditing,
                              maxLines: 2,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Ganti Password ─────────────────────────────
                _buildSectionLabel('Keamanan Akun', Icons.security_outlined),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => setState(() => _showChangePass = !_showChangePass),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _showChangePass
                            ? const Color(0xFF1E3A8A)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _showChangePass
                                  ? [const Color(0xFF1E3A8A), const Color(0xFF1565C0)]
                                  : [const Color(0xFFF0F4FF), const Color(0xFFE0E9FF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: _showChangePass ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ganti Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                'Ubah kata sandi akun Anda',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _showChangePass
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: 18,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showChangePass) ...[
                  const SizedBox(height: 10),
                  _buildChangePasswordForm(),
                ],

                const SizedBox(height: 28),

                // ── Logout Button ────────────────────────────
                GestureDetector(
                  onTap: _onLogout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Keluar dari Akun',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Premium Profile Header ──────────────────────────────
  Widget _buildProfileHeader(String name, String jabatan, String initials) {
    return Container(
      width: double.infinity,
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
        children: [
          const SizedBox(height: 48),
          // Avatar with rings
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              // Middle ring
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
              ),
              // Avatar
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              jabatan,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildSectionLabel(String title, IconData icon, {List<Widget>? actions}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
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
        Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        if (actions != null) ...actions,
      ],
    );
  }

  Widget _buildHeaderAction({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFBBBBBB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 64);
  }

  // _buildInfoCard and _buildReadOnlyRow are replaced by _buildInfoRow and _buildDivider above

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    Color iconColor = const Color(0xFF1E3A8A),
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 16 : 12),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 2 : 0),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                isEditing
                    ? TextFormField(
                        controller: controller,
                        validator: validator,
                        keyboardType: keyboardType,
                        maxLines: maxLines,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: iconColor, width: 1.5)),
                        ),
                      )
                    : Text(
                        controller.text.isEmpty ? '-' : controller.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E4EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _passFormKey,
        child: Column(
          children: [
            _buildPassField(
              controller: _oldPassCtrl,
              label: 'Password Lama',
              obscure: _obscureOld,
              toggleObscure: () => setState(() => _obscureOld = !_obscureOld),
              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildPassField(
              controller: _newPassCtrl,
              label: 'Password Baru',
              obscure: _obscureNew,
              toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildPassField(
              controller: _confirmPassCtrl,
              label: 'Konfirmasi Password Baru',
              obscure: _obscureConfirm,
              toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v != _newPassCtrl.text) return 'Password tidak cocok';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSavingPass ? null : _onChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSavingPass
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Simpan Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E4EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.6),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFFAAAAAA),
            size: 20,
          ),
          onPressed: toggleObscure,
        ),
      ),
    );
  }
}
