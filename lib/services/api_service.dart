import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Ganti dengan IP komputer Anda (yang menjalankan Laravel).
/// Cara cek IP: jalankan `ipconfig` di CMD, cari IPv4 Address.
/// Jangan pakai 'localhost' atau '127.0.0.1' dari HP fisik!
const String kBaseUrl = 'http://192.168.1.14:8080/api/mobile';

/// ───────────────────────────────────────────c──────
/// Model sederhana untuk User & PresensiRecord
/// ─────────────────────────────────────────────────

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? foto;
  final Map<String, dynamic>? pegawai;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.foto,
    this.pegawai,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      foto: json['foto'] as String?,
      pegawai: json['pegawai'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'foto': foto,
      'pegawai': pegawai,
    };
  }
}

class PresensiRecord {
  final int? id;
  final String tanggal;
  final String? jamMasuk;
  final String? jamKeluar;
  final int telatMenit;
  final String status;
  final String? approvalStatus;
  final String? keterangan;

  const PresensiRecord({
    this.id,
    required this.tanggal,
    this.jamMasuk,
    this.jamKeluar,
    this.telatMenit = 0,
    required this.status,
    this.approvalStatus,
    this.keterangan,
  });

  factory PresensiRecord.fromJson(Map<String, dynamic> json) {
    return PresensiRecord(
      id: json['id'] as int?,
      tanggal: json['tanggal'] as String,
      jamMasuk: json['jam_masuk'] as String?,
      jamKeluar: json['jam_keluar'] as String?,
      telatMenit: (json['telat_menit'] as int?) ?? 0,
      status: json['status'] as String? ?? 'Alpa',
      approvalStatus: json['approval_status'] as String?,
      keterangan: json['keterangan'] as String?,
    );
  }

  /// Konversi jam_masuk (format 'HH:mm:ss') menjadi DateTime
  DateTime? get clockInTime {
    if (jamMasuk == null) return null;
    return _parseDateTime(tanggal, jamMasuk!);
  }

  /// Konversi jam_keluar (format 'HH:mm:ss') menjadi DateTime
  DateTime? get clockOutTime {
    if (jamKeluar == null) return null;
    return _parseDateTime(tanggal, jamKeluar!);
  }

  DateTime _parseDateTime(String date, String time) {
    return DateTime.parse('$date $time');
  }
}

/// Model untuk record Cuti / Izin / Sakit
class CutiRecord {
  final String? batchId;
  final String tanggalMulai;
  final String tanggalSelesai;
  final int durasi;
  final String jenis; // 'Cuti', 'Izin', 'Sakit'
  final String approvalStatus; // 'Pending', 'Approved', 'Rejected'
  final String? keterangan;
  final String? suratDokter;
  final DateTime? createdAt;

  const CutiRecord({
    this.batchId,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.durasi,
    required this.jenis,
    required this.approvalStatus,
    this.keterangan,
    this.suratDokter,
    this.createdAt,
  });

  factory CutiRecord.fromJson(Map<String, dynamic> json) {
    return CutiRecord(
      batchId: json['batch_id'] as String?,
      tanggalMulai: json['tanggal_mulai'] as String,
      tanggalSelesai: json['tanggal_selesai'] as String,
      durasi: json['durasi'] as int? ?? 1,
      jenis: json['jenis'] as String,
      approvalStatus: json['approval_status'] as String,
      keterangan: json['keterangan'] as String?,
      suratDokter: json['surat_dokter'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// ─────────────────────────────────────────────────
/// ApiService — singleton untuk semua request ke Laravel
/// ─────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _biometricKey = 'biometric_enabled';

  /// ── Token management ──────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await clearUser(); // Clear user data on logout too
  }

  Future<bool> get isLoggedIn async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// ── User Management ───────────────────────────

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        return UserModel.fromJson(jsonDecode(userStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// ── Biometric Management ──────────────────────

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
  }

  /// ── Headers ───────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// ── Auth: Login ───────────────────────────────

  /// Mengembalikan [UserModel] jika berhasil, melempar [Exception] jika gagal.
  Future<UserModel> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/login'),
      headers: _publicHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && data['success'] == true) {
      await saveToken(data['token'] as String);
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw Exception(
      data['message'] ?? 'Login gagal. Cek koneksi atau credential Anda.',
    );
  }

  /// ── Auth: Logout ──────────────────────────────

  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(Uri.parse('$kBaseUrl/logout'), headers: headers);
    } catch (e) {
      // Ignore error if network fails during logout
    } finally {
      await clearToken();
    }
  }

  /// ── Auth: Update Profil ────────────────────────

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$kBaseUrl/profile'),
      headers: headers,
      body: jsonEncode({'name': name, 'phone': phone, 'alamat': address}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && data['success'] == true) {
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await saveUser(user);
      return user;
    }

    throw Exception(data['message'] ?? 'Gagal memperbarui profil.');
  }

  /// ── Auth: Ganti Password ──────────────────────

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$kBaseUrl/change-password'),
      headers: headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Gagal mengubah password.');
    }
  }

  /// ── Auth: Ambil profil user ───────────────────

  Future<UserModel> getMe() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$kBaseUrl/me'),
      headers: headers,
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil data profil.');
  }

  /// ── Presensi: Riwayat ─────────────────────────

  /// Mengembalikan map dengan keys: 'presensi', 'today', 'has_clocked_in', 'has_clocked_out', 'ringkasan'
  Future<Map<String, dynamic>> getPresensi({int? bulan, int? tahun}) async {
    final headers = await _authHeaders();
    final b = bulan ?? DateTime.now().month;
    final t = tahun ?? DateTime.now().year;

    final uri = Uri.parse(
      '$kBaseUrl/presensi',
    ).replace(queryParameters: {'bulan': b.toString(), 'tahun': t.toString()});

    final cacheKey = 'presensi_cache_${b}_${t}';
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 7));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Cache successful response
        await prefs.setString(cacheKey, response.body);

        final list = (data['presensi'] as List<dynamic>)
            .map((e) => PresensiRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        final todayJson = data['today'];
        final today = todayJson != null
            ? PresensiRecord.fromJson(todayJson as Map<String, dynamic>)
            : null;

        return {
          'presensi': list,
          'today': today,
          'jadwal_today': data['jadwal_today'],
          'jadwal_upcoming': data['jadwal_upcoming'],
          'has_clocked_in': data['has_clocked_in'] as bool? ?? false,
          'has_clocked_out': data['has_clocked_out'] as bool? ?? false,
          'ringkasan':
              data['ringkasan'] as Map<String, dynamic>? ??
              {'hadir': 0, 'telat': 0, 'alpha': 0},
        };
      }
      throw Exception(data['message'] ?? 'Gagal mengambil data presensi.');
    } catch (e) {
      // Fallback to cache if request fails (e.g. offline)
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        final data = jsonDecode(cachedStr) as Map<String, dynamic>;
        final list = (data['presensi'] as List<dynamic>)
            .map((e) => PresensiRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        final todayJson = data['today'];
        final today = todayJson != null
            ? PresensiRecord.fromJson(todayJson as Map<String, dynamic>)
            : null;

        return {
          'presensi': list,
          'today': today,
          'jadwal_today': data['jadwal_today'],
          'jadwal_upcoming': data['jadwal_upcoming'],
          'has_clocked_in': data['has_clocked_in'] as bool? ?? false,
          'has_clocked_out': data['has_clocked_out'] as bool? ?? false,
          'ringkasan':
              data['ringkasan'] as Map<String, dynamic>? ??
              {'hadir': 0, 'telat': 0, 'alpha': 0},
          'is_offline_cache': true,
        };
      }
      rethrow;
    }
  }

  /// ── Presensi: Clock In ────────────────────────

  Future<PresensiRecord> clockIn({
    required double latitude,
    required double longitude,
    required bool isLocationValid,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$kBaseUrl/presensi/clock-in'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'is_location_valid': isLocationValid,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PresensiRecord.fromJson(data['presensi'] as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Gagal melakukan absen masuk.');
  }

  /// ── Presensi: Clock Out ───────────────────────

  Future<PresensiRecord> clockOut({
    required double latitude,
    required double longitude,
    required bool isLocationValid,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$kBaseUrl/presensi/clock-out'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'is_location_valid': isLocationValid,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PresensiRecord.fromJson(data['presensi'] as Map<String, dynamic>);
    }

    throw Exception(data['message'] ?? 'Gagal melakukan absen pulang.');
  }

  /// ── Cuti: Daftar pengajuan ────────────────────

  Future<List<CutiRecord>> getCutiList({int? bulan, int? tahun}) async {
    final headers = await _authHeaders();
    final b = bulan ?? DateTime.now().month;
    final t = tahun ?? DateTime.now().year;

    final uri = Uri.parse(
      '$kBaseUrl/cuti',
    ).replace(queryParameters: {'bulan': b.toString(), 'tahun': t.toString()});

    final cacheKey = 'cuti_list_cache_${b}_${t}';
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 7));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, response.body);

        return (data['pengajuan'] as List<dynamic>)
            .map((e) => CutiRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(data['message'] ?? 'Gagal mengambil data pengajuan.');
    } catch (e) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        final data = jsonDecode(cachedStr) as Map<String, dynamic>;
        return (data['pengajuan'] as List<dynamic>)
            .map((e) => CutiRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// ── Cuti: Ambil jatah cuti ───────────────────

  Future<Map<String, dynamic>> getCutiQuota() async {
    final headers = await _authHeaders();
    final cacheKey = 'cuti_quota_cache';
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(Uri.parse('$kBaseUrl/cuti/quota'), headers: headers)
          .timeout(const Duration(seconds: 7));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, response.body);
        return data['quota'] as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? 'Gagal mengambil jatah cuti.');
    } catch (e) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        final data = jsonDecode(cachedStr) as Map<String, dynamic>;
        return data['quota'] as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// ── Cuti: Kirim pengajuan baru ────────────────

  /// [jenis] harus salah satu: 'Cuti', 'Izin', 'Sakit'
  Future<Map<String, dynamic>> submitCuti({
    required String jenis,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required String keterangan,
    String? suratDokterPath,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$kBaseUrl/cuti');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields['jenis'] = jenis
      ..fields['tanggal_mulai'] =
          '${tanggalMulai.year}-${tanggalMulai.month.toString().padLeft(2, '0')}-${tanggalMulai.day.toString().padLeft(2, '0')}'
      ..fields['tanggal_selesai'] =
          '${tanggalSelesai.year}-${tanggalSelesai.month.toString().padLeft(2, '0')}-${tanggalSelesai.day.toString().padLeft(2, '0')}'
      ..fields['keterangan'] = keterangan;

    if (suratDokterPath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('surat_dokter', suratDokterPath),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal mengirim pengajuan.');
  }
}
