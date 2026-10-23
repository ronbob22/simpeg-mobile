import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';

class KonfirmasiPengajuanCutiScreen extends StatefulWidget {
  final String jenisCutiText;
  final String jenisCutiCode;
  final String masaKerjaText;
  final String masaKerjaTahun;
  final String startDate;
  final String endDate;
  final int lamaCutiHari;
  final String alasanCuti;
  final String alamat;

  const KonfirmasiPengajuanCutiScreen({
    super.key,
    required this.jenisCutiText,
    required this.jenisCutiCode,
    required this.masaKerjaText,
    required this.masaKerjaTahun,
    required this.startDate,
    required this.endDate,
    required this.lamaCutiHari,
    required this.alasanCuti,
    required this.alamat,
  });

  @override
  State<KonfirmasiPengajuanCutiScreen> createState() =>
      _KonfirmasiPengajuanCutiScreenState();
}

class _KonfirmasiPengajuanCutiScreenState
    extends State<KonfirmasiPengajuanCutiScreen> {
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;

  Future<void> _simpanPendingCutiKeLokal(String tokenCuti) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userInfo = await _apiService.getUserInfo();
      final dataUser = userInfo['data'] ?? userInfo['user'] ?? userInfo;
      final String nipPemohon = (dataUser['nip'] ?? '').toString();

      final Map<String, dynamic> itemBaru = {
        'nip_pemohon': nipPemohon,
        'jenis_cuti': widget.jenisCutiText,
        'jenis_cuti_text': widget.jenisCutiText,
        'start_date': widget.startDate,
        'end_date': widget.endDate,
        'lamanya_cuti': widget.lamaCutiHari,
        'alasan_cuti': widget.alasanCuti,
        'alamat_cuti': widget.alamat,
        'proses_id': 1,
        'proses_terakhir_cuti': 'Pengajuan Baru',
        'proses_text': 'Menunggu Verifikasi UP',
        'created_at': DateTime.now().toIso8601String(),
        'up_sign_at': null,
        'atasan_langsung_sign_at': null,
        'pejabat_sign_at': null,
        'active': 1,
        'ask_undo': 0,
        'token_cuti': tokenCuti,
      };

      final key = 'active_permohonan_$nipPemohon';
      final existingStr = prefs.getString(key);
      List<dynamic> list = [];
      if (existingStr != null && existingStr.isNotEmpty) {
        try {
          list = jsonDecode(existingStr) as List<dynamic>;
        } catch (_) {}
      }

      list.removeWhere((el) =>
          (tokenCuti.isNotEmpty && el['token_cuti'] == tokenCuti) ||
          (el['start_date'] == widget.startDate && el['end_date'] == widget.endDate));

      list.insert(0, itemBaru);
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _submitPengajuan() async {
    setState(() => _isSubmitting = true);

    try {
      final res = await _apiService.saveTrxCuti(
        masaKerja: widget.masaKerjaTahun,
        jenisCuti: widget.jenisCutiCode,
        startDate: widget.startDate,
        endDate: widget.endDate,
        alasanCuti: widget.alasanCuti,
        alamat: widget.alamat,
      );

      final bool isSuccess = res['status'] == true;
      final msg = res['msg']?.toString() ?? res['message']?.toString() ?? '';

      if (!isSuccess) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 26),
                SizedBox(width: 8),
                Text('Gagal Mengajukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(msg.isEmpty ? 'Cuti tidak dapat diproses oleh sistem.' : msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ],
          ),
        );
        return;
      }

      String extractedToken = '';
      if (msg.contains('/api/detil-cuti/')) {
        extractedToken = msg.split('/api/detil-cuti/').last.trim();
      }

      await _simpanPendingCutiKeLokal(extractedToken);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 26),
              SizedBox(width: 8),
              Text('Berhasil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(msg.isEmpty ? 'Permohonan cuti berhasil diajukan!' : msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: kSimpegPurple)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'Konfirmasi Pengajuan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEDE9FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'DETAIL PENGAJUAN CUTI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  _buildDetailRow('Jenis Cuti', widget.jenisCutiText),
                  _buildDetailRow('Masa Kerja', widget.masaKerjaText),
                  _buildDetailRow('Mulai Cuti', widget.startDate),
                  _buildDetailRow('Selesai Cuti', widget.endDate),
                  _buildDetailRow('Lama Cuti', '${widget.lamaCutiHari} hari'),
                  _buildDetailRow('Alasan Cuti', widget.alasanCuti),
                  _buildDetailRow('Alamat', widget.alamat, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Pastikan data yang Anda ajukan sudah benar sebelum dikirim.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitPengajuan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3949AB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Ajukan Sekarang',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        if (!isLast) const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}