import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Ganti dengan IP komputer Anda (yang menjalankan Laravel).
/// Cara cek IP: jalankan `ipconfig` di CMD, cari IPv4 Address.
/// Jangan pakai 'localhost' atau '127.0.0.1' dari HP fisik!
const String kBaseUrl = 'http://192.168.1.10:8080/api/mobile';

/// ─────────────────────────────────────────────────
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
}

class PresensiRecord {
  final int id;
  final String tanggal;
  final String? jamMasuk;
  final String? jamKeluar;
  final String status;
  final String approvalStatus;
  final String? keterangan;

  const PresensiRecord({
    required this.id,
    required this.tanggal,
    this.jamMasuk,
    this.jamKeluar,
    required this.status,
    required this.approvalStatus,
    this.keterangan,
  });

  factory PresensiRecord.fromJson(Map<String, dynamic> json) {
    return PresensiRecord(
      id: json['id'] as int,
      tanggal: json['tanggal'] as String,
      jamMasuk: json['jam_masuk'] as String?,
      jamKeluar: json['jam_keluar'] as String?,
      status: json['status'] as String,
      approvalStatus: json['approval_status'] as String,
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
  }

  Future<bool> get isLoggedIn async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
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
    } finally {
      await clearToken();
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

  /// Mengembalikan map dengan keys: 'presensi', 'today', 'has_clocked_in', 'has_clocked_out'
  Future<Map<String, dynamic>> getPresensi({int? bulan, int? tahun}) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$kBaseUrl/presensi').replace(
      queryParameters: {
        if (bulan != null) 'bulan': bulan.toString(),
        if (tahun != null) 'tahun': tahun.toString(),
      },
    );

    final response = await http.get(uri, headers: headers);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
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
        'has_clocked_in': data['has_clocked_in'] as bool,
        'has_clocked_out': data['has_clocked_out'] as bool,
      };
    }

    throw Exception(data['message'] ?? 'Gagal mengambil data presensi.');
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
    final uri = Uri.parse('$kBaseUrl/cuti').replace(
      queryParameters: {
        if (bulan != null) 'bulan': bulan.toString(),
        if (tahun != null) 'tahun': tahun.toString(),
      },
    );

    final response = await http.get(uri, headers: headers);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return (data['pengajuan'] as List<dynamic>)
          .map((e) => CutiRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(data['message'] ?? 'Gagal mengambil data pengajuan.');
  }

  /// ── Cuti: Ambil jatah cuti ───────────────────

  Future<Map<String, dynamic>> getCutiQuota() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$kBaseUrl/cuti/quota'),
      headers: headers,
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data['quota'] as Map<String, dynamic>;
    }

    throw Exception(data['message'] ?? 'Gagal mengambil jatah cuti.');
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
