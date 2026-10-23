import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'konfirmasi_pengajuan_cuti_screen.dart';

class FormPengajuanCutiScreen extends StatefulWidget {
  final String jenisCuti;

  const FormPengajuanCutiScreen({
    super.key,
    required this.jenisCuti,
  });

  @override
  State<FormPengajuanCutiScreen> createState() =>
      _FormPengajuanCutiScreenState();
}

class _FormPengajuanCutiScreenState extends State<FormPengajuanCutiScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _alasanController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();

  static const String _baseSikepFotoUrl =
      'https://sikep.mahkamahagung.go.id/uploads/foto_pegawai';

  bool _isLoadingUser = true;
  String _namaPegawai = '-';
  String _nipPegawai = '-';
  String _jabatanPegawai = '-';
  String? _fotoPegawai;

  int _masaKerjaTahun = 0;
  int _masaKerjaBulan = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCalculating = false;
  int _lamaCutiHari = 0;

  int _sisaTahunIni = 0;
  int _sisaTahunLalu = 0;
  int _sisaCutiSakit = 0;
  int _saldoTertahan = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _alasanController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _hitungMasaKerjaReal(Map<String, dynamic> dataUser, String rawNip) {
    DateTime? tmtDate;

    // 1. Cek jika backend memiliki field TMT
    final rawTmt = dataUser['tmt_pns'] ??
        dataUser['tmt_cpns'] ??
        dataUser['tmt'] ??
        dataUser['tmt_golongan'] ??
        dataUser['tgl_sk'];

    if (rawTmt != null && rawTmt.toString().isNotEmpty && rawTmt.toString() != 'null') {
      tmtDate = DateTime.tryParse(rawTmt.toString().split(' ')[0]);
    }

    // 2. Ekstrak langsung dari string NIP (YYYYMMDD YYYYMM X XXX)
    final cleanNip = rawNip.replaceAll(RegExp(r'\D'), '');
    if (tmtDate == null && cleanNip.length >= 14) {
      try {
        final thnCpns = int.parse(cleanNip.substring(8, 12));
        final blnCpns = int.parse(cleanNip.substring(12, 14));
        if (thnCpns > 1950 && thnCpns <= DateTime.now().year && blnCpns >= 1 && blnCpns <= 12) {
          tmtDate = DateTime(thnCpns, blnCpns, 1);
        }
      } catch (e) {
        debugPrint('Error parse NIP untuk TMT: $e');
      }
    }

    if (tmtDate != null) {
      final now = DateTime.now();
      int tahun = now.year - tmtDate.year;
      int bulan = now.month - tmtDate.month;

      if (bulan < 0) {
        tahun--;
        bulan += 12;
      }

      _masaKerjaTahun = tahun >= 0 ? tahun : 0;
      _masaKerjaBulan = bulan >= 0 ? bulan : 0;
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final userInfo = await _apiService.getUserInfo();
      final dataUser = userInfo['data'] ?? userInfo['user'] ?? userInfo;

      final saldoInfo = await _apiService.getSaldoCuti();
      Map<String, dynamic> dataSaldo = {};
      if (saldoInfo['data'] is Map) {
        dataSaldo = saldoInfo['data'] as Map<String, dynamic>;
      } else if (saldoInfo is Map<String, dynamic>) {
        dataSaldo = saldoInfo;
      }

      final String nipRaw = (dataUser['nip'] ?? '').toString();

      // Hitung masa kerja sebelum setState agar nilainya langsung masuk ke tampilan UI
      _hitungMasaKerjaReal(dataUser, nipRaw);

      if (mounted) {
        setState(() {
          _namaPegawai = dataUser['nama'] ?? dataUser['name'] ?? '-';
          _nipPegawai = nipRaw.isNotEmpty ? nipRaw : '-';
          _jabatanPegawai = dataUser['jabatan'] ?? dataUser['bagian'] ?? '-';
          _fotoPegawai = dataUser['foto'];

          _sisaTahunIni = dataSaldo['sisa_tahun_ini'] ?? dataSaldo['sisa_n'] ?? 0;
          _sisaTahunLalu = dataSaldo['sisa_tahun_lalu'] ?? dataSaldo['sisa_n_1'] ?? 0;
          _sisaCutiSakit = dataSaldo['sisa_cuti_sakit'] ?? 0;
          _saldoTertahan = dataSaldo['saldo_tertahan'] ??
              dataSaldo['tertahan'] ??
              dataSaldo['cuti_tertahan'] ??
              0;

          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat profil/saldo: $e');
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _pilihTanggal(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kSimpegPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });

      if (_startDate != null && _endDate != null) {
        _hitungDurasiCuti();
      }
    }
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'dd/mm/yyyy';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _hitungDurasiCuti() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isCalculating = true);

    try {
      final res = await _apiService.getInfoCuti(
        startDate: _formatApiDate(_startDate!),
        endDate: _formatApiDate(_endDate!),
        jenisCuti: widget.jenisCuti,
      );

      final int lama = res['lama_cuti'] ??
          res['data']?['lama_cuti'] ??
          (_endDate!.difference(_startDate!).inDays + 1);

      if (mounted) {
        setState(() => _lamaCutiHari = lama);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lamaCutiHari = _endDate!.difference(_startDate!).inDays + 1;
        });
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nipFromProvider = context.watch<AuthProvider>().nip;
    final nipFinal = _nipPegawai != '-' ? _nipPegawai : (nipFromProvider ?? '-');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'Form Pengajuan Cuti',
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
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator(color: kSimpegPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: ClipOval(
                              child: (_fotoPegawai != null && _fotoPegawai!.isNotEmpty)
                                  ? Image.network(
                                      '$_baseSikepFotoUrl/$_fotoPegawai',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Color(0xFF94A3B8),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _namaPegawai,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  nipFinal,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _jabatanPegawai,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Cuti',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.jenisCuti.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Menampilkan Hasil Kalkulasi Masa Kerja ASN
                          const Text(
                            'Masa Kerja',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildMasaKerjaBox('$_masaKerjaTahun', 'Tahun'),
                              const SizedBox(width: 14),
                              _buildMasaKerjaBox('$_masaKerjaBulan', 'Bulan'),
                            ],
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Mulai Cuti',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _buildDateInputBox(
                            text: _formatDisplayDate(_startDate),
                            isSelected: _startDate != null,
                            onTap: () => _pilihTanggal(true),
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Selesai Cuti',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _buildDateInputBox(
                            text: _formatDisplayDate(_endDate),
                            isSelected: _endDate != null,
                            onTap: () => _pilihTanggal(false),
                          ),
                          const SizedBox(height: 20),

                          if (_startDate != null && _endDate != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.work_outline_rounded, color: Color(0xFF6366F1), size: 28),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Lama Pengajuan Cuti',
                                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 2),
                                          _isCalculating
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : Text(
                                                  '$_lamaCutiHari Hari Kerja',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF3B82F6),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMiniSaldoBox(
                                          title: 'Sisa Tahun Ini',
                                          value: '$_sisaTahunIni',
                                          color: const Color(0xFF10B981),
                                          icon: Icons.calendar_today_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMiniSaldoBox(
                                          title: 'Sisa Tahun Lalu',
                                          value: '$_sisaTahunLalu',
                                          color: const Color(0xFF3B82F6),
                                          icon: Icons.event_note_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMiniSaldoBox(
                                          title: 'Sisa Cuti Sakit',
                                          value: '$_sisaCutiSakit',
                                          color: const Color(0xFFF59E0B),
                                          icon: Icons.add_box_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMiniSaldoBox(
                                          title: 'Saldo Tertahan',
                                          value: '$_saldoTertahan',
                                          color: const Color(0xFFA855F7),
                                          icon: Icons.watch_later_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Alasan Cuti',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _alasanController,
                            maxLines: 3,
                            validator: (v) => (v == null || v.isEmpty) ? 'Alasan cuti wajib diisi' : null,
                            decoration: InputDecoration(
                              hintText: 'Tuliskan alasan permohonan cuti...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Alamat selama Cuti',
                            style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _alamatController,
                            maxLines: 2,
                            validator: (v) => (v == null || v.isEmpty) ? 'Alamat wajib diisi' : null,
                            decoration: InputDecoration(
                              hintText: 'Alamat lengkap',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          if (_startDate == null || _endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pilih tanggal mulai dan selesai cuti')),
                            );
                            return;
                          }

                          String kodeCuti = 'CT';
                          final jcLower = widget.jenisCuti.toLowerCase();
                          if (jcLower.contains('sakit')) {
                            kodeCuti = 'CS';
                          } else if (jcLower.contains('besar')) {
                            kodeCuti = 'CB';
                          } else if (jcLower.contains('melahirkan')) {
                            kodeCuti = 'CM';
                          } else if (jcLower.contains('penting')) {
                            kodeCuti = 'CAP';
                          } else if (jcLower.contains('tanggungan')) {
                            kodeCuti = 'CLTN';
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KonfirmasiPengajuanCutiScreen(
                                jenisCutiText: widget.jenisCuti,
                                jenisCutiCode: kodeCuti,
                                masaKerjaText: '$_masaKerjaTahun Tahun $_masaKerjaBulan Bulan',
                                masaKerjaTahun: '$_masaKerjaTahun',
                                startDate: _formatApiDate(_startDate!),
                                endDate: _formatApiDate(_endDate!),
                                lamaCutiHari: _lamaCutiHari,
                                alasanCuti: _alasanController.text.trim(),
                                alamat: _alamatController.text.trim(),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3949AB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Lanjut ke Konfirmasi',
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
            ),
    );
  }

  Widget _buildMasaKerjaBox(String angka, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            angka,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInputBox({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSaldoBox({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}