import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_constants.dart';
import 'secure_storage_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Header untuk endpoint SETELAH login (dashboard, saldo, history, dll).
  /// Beda dari login: pakai token HASIL LOGIN (bukan token statis),
  /// dan wajib sertakan device-id & device-name yang SAMA seperti saat login.
  Future<Map<String, String>> _authHeaders() async {
    final token = await _secureStorage.getToken();
    final deviceId = await _secureStorage.getOrCreateDeviceId();

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'device-id': deviceId,
      'device-name': ApiConstants.deviceName,
    };
  }

  /// Login pakai NIP dan password (pwd).
  /// Endpoint ini khusus pakai token STATIS di Authorization.
  Future<Map<String, dynamic>> login(String nip, String password) async {
    try {
      final deviceId = await _secureStorage.getOrCreateDeviceId();

      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${ApiConstants.staticApiToken}',
        },
        body: {
          'nip': nip,
          'pwd': password,
          'device_name': ApiConstants.deviceName,
          'device_id': deviceId,
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['status'] == true;

      if (success) {
        final token = data['token']?.toString();
        if (token != null) {
          await _secureStorage.saveToken(token);
        }
        return data;
      } else {
        throw ApiException(
          data['msg']?.toString() ?? 'Login gagal. Periksa NIP dan password.',
        );
      }
    } on http.ClientException {
      throw ApiException('Tidak bisa terhubung ke server. Periksa koneksi internet.');
    } on FormatException {
      throw ApiException('Respons server tidak valid.');
    }
  }

  Future<Map<String, dynamic>> getUserInfo() async {
    final response = await http.get(
      Uri.parse(ApiConstants.userInfo),
      headers: await _authHeaders(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(data['msg']?.toString() ?? 'Gagal mengambil data profil.');
    }
    return data;
  }

  /// Ambil data dashboard.
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse(ApiConstants.dashboard),
      headers: await _authHeaders(),
    );
    debugPrint('DASHBOARD RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(data['msg']?.toString() ?? 'Gagal mengambil data dashboard.');
    }
    return data;
  }

  /// Ambil data saldo cuti pribadi pengguna.
  Future<Map<String, dynamic>> getSaldoCuti() async {
    final response = await http.get(
      Uri.parse(ApiConstants.saldoCuti),
      headers: await _authHeaders(),
    );
    debugPrint('SALDO CUTI RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(data['msg']?.toString() ?? 'Gagal mengambil data saldo cuti.');
    }
    return data;
  }

  /// Mengambil riwayat pengajuan cuti pribadi
  Future<Map<String, dynamic>> getHistoryCutiPersonal({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConstants.historyCutiPersonal(page)),
      headers: await _authHeaders(),
    );

    debugPrint('HISTORY CUTI RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ?? 'Gagal mengambil riwayat cuti.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> getListPermohonanCuti({int tahapanId = 1}) async {
    final url = Uri.parse(ApiConstants.listPermohonanCuti(tahapanId));
    final headers = await _authHeaders();
    final response = await http.get(url, headers: headers);

    debugPrint('URL: $url');
    debugPrint('LIST PERMOHONAN STATUS: ${response.statusCode}');
    debugPrint('LIST PERMOHONAN BODY: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ?? 
        data['message']?.toString() ?? 
        'Error ${response.statusCode}: ${response.body}',
      );
    }
    return data;
  }

  /// Menghitung durasi hari kerja dan info kuota berdasarkan rentang tanggal
  Future<Map<String, dynamic>> getInfoCuti({
    required String startDate,
    required String endDate,
    required String jenisCuti,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.infoCuti),
      headers: headers,
      body: {
        'start_date': startDate,
        'end_date': endDate,
        'jenis_cuti': jenisCuti,
      },
    );

    debugPrint('INFO CUTI RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  /// Mencari saldo cuti pegawai lain berdasarkan nama
  Future<Map<String, dynamic>> searchSaldoNama(String nama) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.searchSaldoNama),
      headers: headers,
      body: {
        'nama_pegawai': nama, // Menyesuaikan key API backend
      },
    );

    debugPrint('SEARCH SALDO RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ?? 'Gagal mencari saldo pegawai.',
      );
    }
    return data;
  }

  /// Mengirim transaksi pengajuan cuti baru
  Future<Map<String, dynamic>> saveTrxCuti({
    required String masaKerja,
    required String jenisCuti,
    required String startDate,
    required String endDate,
    required String alasanCuti,
    required String alamat,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.saveTrxCuti),
      headers: headers,
      body: {
        'masa_kerja': masaKerja,
        'jenis_cuti': jenisCuti,
        'start_date': startDate,
        'end_date': endDate,
        'alasan_cuti': alasanCuti,
        'alamat': alamat,
      },
    );

    debugPrint('SAVE TRX CUTI RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        data['msg']?.toString() ??
        data['message']?.toString() ??
        'Gagal mengajukan cuti.',
      );
    }
    return data;
  }

  /// Mengambil detail permohonan cuti berdasarkan token_cuti
  Future<Map<String, dynamic>> getDetilCuti(String tokenCuti) async {
    final response = await http.get(
      Uri.parse(ApiConstants.detilCuti(tokenCuti)),
      headers: await _authHeaders(),
    );

    debugPrint('DETIL CUTI RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
        data['message']?.toString() ??
        'Gagal mengambil detail cuti.',
      );
    }
    return data;
  }

  /// Melakukan konfirmasi/verifikasi cuti oleh Unit Kepegawaian (UP)
  Future<Map<String, dynamic>> confirmCutiUp({
    required String tokenCuti,
    required String catatan,
    required bool izin,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.confirmCutiUp),
      headers: headers,
      body: {
        'token_cuti': tokenCuti,
        'catatan': catatan,
        'izin': izin ? 'true' : 'false',
        'action': 'set',
      },
    );

    debugPrint('CONFIRM CUTI UP RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
        data['message']?.toString() ??
        'Gagal memproses verifikasi cuti.',
      );
    }
    return data;
  }

  /// Konfirmasi/Verifikasi oleh Atasan Langsung
  Future<Map<String, dynamic>> confirmCutiAtasan({
    required String tokenCuti,
    required String catatan,
    required bool izin,
    String action = 'set',
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.confirmCutiAtasan),
      headers: headers,
      body: {
        'token_cuti': tokenCuti,
        'catatan': catatan,
        'catatan_atasan': catatan,
        'izin': izin ? 'true' : 'false',
        'status': izin ? '1' : '0',
        'action': action,
      },
    );

    debugPrint('CONFIRM ATASAN RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
            data['message']?.toString() ??
            'Gagal memproses verifikasi atasan.',
      );
    }
    return data;
  }

  /// Konfirmasi/Persetujuan Akhir oleh Pejabat Berwenang
  Future<Map<String, dynamic>> confirmCutiPejabat({
    required String tokenCuti,
    required String catatan,
    required bool izin,
    String action = 'set',
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.confirmCutiPejabat),
      headers: headers,
      body: {
        'token_cuti': tokenCuti,
        'catatan': catatan,
        'catatan_pejabat': catatan,
        'izin': izin ? 'true' : 'false',
        'status': izin ? '1' : '0',
        'action': action,
      },
    );

    debugPrint('CONFIRM PEJABAT RESPONSE [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
            data['message']?.toString() ??
            'Gagal memproses persetujuan pejabat.',
      );
    }
    return data;
  }

  /// Mengajukan pembatalan cuti oleh pegawai pemohon
  Future<Map<String, dynamic>> cancelCutiMob({
    required String tokenCuti,
    required String namaPegawai,
    String? alasan,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/cancel-cuti-mob');

    final Map<String, String> body = {
      'token_cuti': tokenCuti,
      'nama_pegawai': namaPegawai,
    };

    if (alasan != null && alasan.isNotEmpty) {
      body['alasan'] = alasan;
      body['catatan'] = alasan;
    }

    debugPrint('>>> REQUEST CANCEL CUTI: $body');

    final response = await http.post(
      uri,
      headers: headers,
      body: body,
    );

    debugPrint('>>> RESPONSE CANCEL CUTI [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
        data['message']?.toString() ??
        'Gagal mengajukan pembatalan cuti.',
      );
    }
    return data;
  }

  /// Mengambil daftar permohonan pembatalan cuti (Khusus Kepegawaian / UP)
  Future<Map<String, dynamic>> getListAskCancel({
    String? namaPegawai,
    String? tokenCuti,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(ApiConstants.listAskCancel);

    final Map<String, String> body = {};
    if (namaPegawai != null && namaPegawai.isNotEmpty) {
      body['nama_pegawai'] = namaPegawai;
    }
    if (tokenCuti != null && tokenCuti.isNotEmpty) {
      body['token_cuti'] = tokenCuti;
    }

    debugPrint('>>> REQUEST LIST ASK CANCEL: $body');

    final response = await http.post(
      uri,
      headers: headers,
      body: body,
    );

    debugPrint('>>> RESPONSE LIST ASK CANCEL [${response.statusCode}]: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        data['msg']?.toString() ??
        data['message']?.toString() ??
        'Gagal memuat daftar permohonan pembatalan.',
      );
    }
    return data;
  }

  Future<void> logout() async {
    try {
      await http.post(Uri.parse(ApiConstants.logout), headers: await _authHeaders());
    } finally {
      await _secureStorage.deleteToken();
      await _secureStorage.deleteDeviceId();
    }
  }
}