import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';

class DetailCutiScreen extends StatefulWidget {
  final String tokenCuti;

  const DetailCutiScreen({
    super.key,
    required this.tokenCuti,
  });

  @override
  State<DetailCutiScreen> createState() => _DetailCutiScreenState();
}

class _DetailCutiScreenState extends State<DetailCutiScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _detail;

  static const String _baseSikepFotoUrl =
      'https://sikep.mahkamahagung.go.id/uploads/foto_pegawai';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getDetilCuti(widget.tokenCuti);

      Map<String, dynamic>? item;
      if (res['data'] is Map && res['data']['data'] is Map) {
        item = res['data']['data'] as Map<String, dynamic>;
      } else if (res['data'] is Map) {
        item = res['data'] as Map<String, dynamic>;
      }

      if (mounted) {
        setState(() => _detail = item);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTanggalIndo(String? rawDate, {bool withTime = false}) {
    if (rawDate == null || rawDate.isEmpty) return '-';

    const List<String> bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    try {
      final clean = rawDate.replaceAll('T', ' ');
      final splitSpace = clean.split(' ');
      final datePart = splitSpace[0];
      final timePart = splitSpace.length > 1 ? splitSpace[1] : '';

      final parts = datePart.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[2]);
        final m = int.parse(parts[1]) - 1;
        final y = parts[0];

        String result = '$d ${bulan[m]} $y';
        if (withTime && timePart.isNotEmpty) {
          final timeSplits = timePart.split(':');
          if (timeSplits.length >= 2) {
            result += ', ${timeSplits[0]}:${timeSplits[1]}';
          }
        }
        return result;
      }
      return rawDate;
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _showCancelDialog() async {
    final alasanCtrl = TextEditingController();
    bool isProcessing = false;
    final String namaPegawai = _detail?['nama'] ?? _detail?['nama_pegawai'] ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
                SizedBox(width: 8),
                Text(
                  'Batalkan Cuti',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Apakah Anda yakin ingin mengajukan pembatalan untuk permohonan cuti ini?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: alasanCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tuliskan alasan pembatalan...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Kembali', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        try {
                          final res = await _apiService.cancelCutiMob(
                            tokenCuti: widget.tokenCuti,
                            namaPegawai: namaPegawai,
                            alasan: alasanCtrl.text.trim(),
                          );

                          if (!mounted) return;
                          Navigator.pop(ctx);

                          final msg = res['msg'] ?? res['message'] ?? 'Permohonan pembatalan berhasil dikirim.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg.toString()),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );

                          await _loadDetail();
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('ApiException: ', '')),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Ya, Batalkan',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showConfirmDialog({required bool isApprove}) async {
    final catatanCtrl = TextEditingController(text: isApprove ? 'acc' : '');
    bool isProcessing = false;

    final bool hasUpSign = _detail?['up_sign_at'] != null &&
        _detail!['up_sign_at'].toString().isNotEmpty &&
        _detail!['up_sign_at'] != 'null';

    final bool hasAtasanSign = _detail?['atasan_langsung_sign_at'] != null &&
        _detail!['atasan_langsung_sign_at'].toString().isNotEmpty &&
        _detail!['atasan_langsung_sign_at'] != 'null';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isApprove ? 'Setujui Permohonan' : 'Tolak Permohonan',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApprove ? 'Masukkan catatan persetujuan:' : 'Masukkan alasan penolakan (wajib):',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catatanCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: isApprove ? 'Tulis catatan...' : 'Tulis alasan penolakan...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        final inputCatatan = catatanCtrl.text.trim();
                        if (!isApprove && inputCatatan.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alasan penolakan wajib diisi!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isProcessing = true);
                        try {
                          final catatan = inputCatatan.isEmpty
                              ? (isApprove ? 'acc' : 'ditolak')
                              : inputCatatan;

                          Map<String, dynamic> res;

                          if (hasUpSign && !hasAtasanSign) {
                            res = await _apiService.confirmCutiAtasan(
                              tokenCuti: widget.tokenCuti,
                              catatan: catatan,
                              izin: isApprove,
                              action: 'set',
                            );
                          } else if (hasAtasanSign) {
                            res = await _apiService.confirmCutiPejabat(
                              tokenCuti: widget.tokenCuti,
                              catatan: catatan,
                              izin: isApprove,
                              action: 'set',
                            );
                          } else {
                            res = await _apiService.confirmCutiUp(
                              tokenCuti: widget.tokenCuti,
                              catatan: catatan,
                              izin: isApprove,
                            );
                          }

                          if (!mounted) return;
                          Navigator.pop(ctx);

                          final msg = res['msg'] ?? res['message'] ?? 'Verifikasi berhasil diproses';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg.toString()),
                              backgroundColor: isApprove ? const Color(0xFF16A34A) : Colors.red.shade700,
                            ),
                          );

                          await _loadDetail();
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('ApiException: ', '')),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isApprove ? 'Setujui' : 'Tolak',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = _detail?['action_confirm'] == true;
    final bool canCancel = _detail?['action_cancel'] == true || _detail?['can_cancel'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Permohonan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: (_isLoading || _detail == null || (!canConfirm && !canCancel))
          ? null
          : _buildBottomActions(canConfirm, canCancel),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kSimpegPurple));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gagal memuat detail: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDetail,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) {
      return const Center(child: Text('Data tidak ditemukan.'));
    }

    final String nama = _detail!['nama'] ?? '-';
    final String nip = _detail!['nip'] ?? '-';
    final String? foto = _detail!['foto'];

    final String jenisCuti = _detail!['jenis_cuti_text'] ?? _detail!['jenis_cuti'] ?? 'Cuti Tahunan';
    final String tglMulai = _formatTanggalIndo(_detail!['start_date']?.toString());
    final String tglSelesai = _formatTanggalIndo(_detail!['end_date']?.toString());
    final String lamaCuti = '${_detail!['lamanya_cuti'] ?? '-'} hari';
    final String alasan = _detail!['alasan_cuti'] ?? '-';
    final String alamat = _detail!['alamat_cuti'] ?? '-';

    // 1. Ekstraksi status penolakan umum
    final String statusStr = (_detail!['proses_terakhir_cuti'] ??
            _detail!['proses_text'] ??
            _detail!['status_text'] ??
            _detail!['status_cuti'] ??
            '')
        .toString()
        .toLowerCase();

    final bool isOverallRejected = statusStr.contains('tolak') ||
        statusStr.contains('batal') ||
        statusStr.contains('reject') ||
        _detail!['status_permohonan'] == 0 ||
        _detail!['status'] == 'ditolak';

    // 2. Evaluasi tanda tangan
    final bool hasUpSign = _detail!['up_sign_at'] != null &&
        _detail!['up_sign_at'].toString().isNotEmpty &&
        _detail!['up_sign_at'] != 'null';

    final bool hasAtasanSign = _detail!['atasan_langsung_sign_at'] != null &&
        _detail!['atasan_langsung_sign_at'].toString().isNotEmpty &&
        _detail!['atasan_langsung_sign_at'] != 'null';

    final bool hasPejabatSign = _detail!['pejabat_sign_at'] != null &&
        _detail!['pejabat_sign_at'].toString().isNotEmpty &&
        _detail!['pejabat_sign_at'] != 'null';

    // 3. Menentukan tahap yang menolak secara akurat:
    bool isPejabatRejected = false;
    bool isAtasanRejected = false;
    bool isUpRejected = false;

    if (isOverallRejected) {
      if (hasPejabatSign || statusStr.contains('pejabat')) {
        isPejabatRejected = true;
      } else if (hasAtasanSign || statusStr.contains('atasan')) {
        isAtasanRejected = true;
      } else {
        isUpRejected = true;
      }
    }

    final String? noteUp = _detail!['catatan_up']?.toString() ?? (isUpRejected ? _detail!['catatan']?.toString() : null);
    final String? noteAtasan = _detail!['catatan_atasan_langsung']?.toString() ?? (isAtasanRejected ? _detail!['catatan']?.toString() : null);
    final String? notePejabat = _detail!['catatan_pejabat']?.toString() ?? (isPejabatRejected ? _detail!['catatan']?.toString() : null);

    return RefreshIndicator(
      color: kSimpegPurple,
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: ClipOval(
                    child: (foto != null && foto.isNotEmpty)
                        ? Image.network(
                            '$_baseSikepFotoUrl/$foto',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 28, color: Color(0xFF94A3B8)),
                          )
                        : const Icon(Icons.person, size: 28, color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NIP: $nip',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9FD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'DETAIL CUTI',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildFieldItem('Jenis Cuti', jenisCuti),
                _buildFieldItem('Mulai Cuti', tglMulai),
                _buildFieldItem('Selesai Cuti', tglSelesai),
                _buildFieldItem('Lama Cuti', lamaCuti),
                _buildFieldItem('Alasan Cuti', alasan),
                _buildFieldItem('Alamat Selama Cuti', alamat, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9FD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'RIWAYAT PERSETUJUAN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // 1. TAHAP KEPEGAWAIAN (UP)
                _buildTimelineItem(
                  title: isUpRejected ? 'Ditolak oleh Kepegawaian' : 'Konfirmasi Kepegawaian',
                  isDone: hasUpSign || isUpRejected,
                  isRejected: isUpRejected,
                  isCancelled: false,
                  dateStr: _formatTanggalIndo(_detail!['up_sign_at']?.toString(), withTime: true),
                  note: noteUp,
                  isLast: false,
                ),

                // 2. TAHAP ATASAN LANGSUNG
                _buildTimelineItem(
                  title: isAtasanRejected ? 'Ditolak oleh Atasan Langsung' : 'Persetujuan Atasan Langsung',
                  isDone: hasAtasanSign || isAtasanRejected,
                  isRejected: isAtasanRejected,
                  isCancelled: isUpRejected,
                  dateStr: _formatTanggalIndo(_detail!['atasan_langsung_sign_at']?.toString(), withTime: true),
                  note: isUpRejected ? null : noteAtasan,
                  isLast: false,
                ),

                // 3. TAHAP PEJABAT
                _buildTimelineItem(
                  title: isPejabatRejected ? 'Ditolak oleh Pejabat' : 'Persetujuan Pejabat',
                  isDone: hasPejabatSign || isPejabatRejected,
                  isRejected: isPejabatRejected,
                  isCancelled: isUpRejected || isAtasanRejected,
                  dateStr: _formatTanggalIndo(_detail!['pejabat_sign_at']?.toString(), withTime: true),
                  note: (isUpRejected || isAtasanRejected) ? null : notePejabat,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFieldItem(String label, String value, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 14),
        if (!isLast) const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required bool isDone,
    bool isRejected = false,
    bool isCancelled = false,
    required String dateStr,
    required String? note,
    required bool isLast,
  }) {
    Color iconColor;
    IconData iconData;

    if (isRejected) {
      iconColor = const Color(0xFFEF4444);
      iconData = Icons.cancel_rounded;
    } else if (isCancelled) {
      iconColor = const Color(0xFFCBD5E1);
      iconData = Icons.remove_circle_outline_rounded;
    } else if (isDone) {
      iconColor = const Color(0xFF16A34A);
      iconData = Icons.check_circle_rounded;
    } else {
      iconColor = const Color(0xFF94A3B8);
      iconData = Icons.access_time_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(iconData, color: iconColor, size: 24),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isRejected
                        ? const Color(0xFFFCA5A5)
                        : (isDone && !isCancelled ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isRejected
                          ? const Color(0xFFDC2626)
                          : (isCancelled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isDone) ...[
                    if (dateStr != '-')
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    if (note != null && note.isNotEmpty && note != '-' && note != 'null') ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF334155),
                            fontWeight: isRejected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ] else if (isCancelled) ...[
                    const Text(
                      'Dibatalkan (Permohonan ditolak pada tahap sebelumnya)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    ),
                  ] else ...[
                    Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Text(
                          'Menunggu proses',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool canConfirm, bool canCancel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Jika akun adalah pemohon dan punya hak batalkan (action_cancel)
            if (canCancel && !canConfirm)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCancelDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: const Text(
                    'Batalkan Permohonan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

            // Jika akun adalah verifikator (Atasan / Pejabat / UP)
            if (canConfirm) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showConfirmDialog(isApprove: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmDialog(isApprove: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}