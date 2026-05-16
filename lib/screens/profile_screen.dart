import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE53935),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPass = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE53935),
        ),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
          // ── Header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF1565C0)],
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    jabatan,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ── Info Cards ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Informasi Pegawai',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    if (!_isEditing)
                      TextButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                // Reset values
                                if (_user != null) {
                                  _nameCtrl.text = _user!.pegawai?['nama'] as String? ?? _user!.name;
                                  _phoneCtrl.text = _user!.pegawai?['no_hp'] as String? ?? '';
                                  _addressCtrl.text = _user!.pegawai?['alamat'] as String? ?? '';
                                }
                              });
                            },
                            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: _isSavingProfile ? null : _onSaveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isSavingProfile
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Simpan', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildInfoCard([
                  _buildReadOnlyRow(Icons.badge_outlined, 'NIK', nik),
                  const Divider(height: 1, indent: 45),
                  _buildReadOnlyRow(Icons.email_outlined, 'Email', email),
                  const Divider(height: 1, indent: 45),
                  _buildReadOnlyRow(Icons.work_outline, 'Jabatan', jabatan),
                  const Divider(height: 1, indent: 45),
                  
                  Form(
                    key: _profileFormKey,
                    child: Column(
                      children: [
                        _buildEditableRow(
                          icon: Icons.person_outline,
                          label: 'Nama',
                          controller: _nameCtrl,
                          isEditing: _isEditing,
                          validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                        ),
                        const Divider(height: 1, indent: 45),
                        _buildEditableRow(
                          icon: Icons.phone_outlined,
                          label: 'No. HP',
                          controller: _phoneCtrl,
                          isEditing: _isEditing,
                          keyboardType: TextInputType.phone,
                        ),
                        const Divider(height: 1, indent: 45),
                        _buildEditableRow(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat',
                          controller: _addressCtrl,
                          isEditing: _isEditing,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Ganti Password ────────────────────────────────
                InkWell(
                  onTap: () => setState(() => _showChangePass = !_showChangePass),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showChangePass
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFE0E4EC),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF1E3A8A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Ganti Password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        Icon(
                          _showChangePass
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showChangePass) ...[
                  const SizedBox(height: 12),
                  _buildChangePasswordForm(),
                ],

                const SizedBox(height: 24),

                // ── Logout Button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFBBBBBB), // Muted for read-only
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: SizedBox(
              width: 70,
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            ),
          ),
          Expanded(
            child: isEditing
                ? TextFormField(
                    controller: controller,
                    validator: validator,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E3A8A))),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      controller.text.isEmpty ? '-' : controller.text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222222),
                      ),
                    ),
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
