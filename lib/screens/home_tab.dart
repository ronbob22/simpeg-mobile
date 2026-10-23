import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'form_pengajuan_cuti_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'Memuat Nama...';

  // Base URL resmi foto SIKEP Mahkamah Agung
  static const String _baseSikepFotoUrl =
      'https://sikep.mahkamahagung.go.id/uploads/foto_pegawai';

  Map<String, dynamic> _summaryCounts = {};
  List<dynamic> _listPegawaiCuti = [];

  final List<Map<String, dynamic>> _kategoriCuti = [
    {
      'title': 'Tahunan',
      'icon': Icons.calendar_month_rounded,
      'color': const Color(0xFFEF4444),
      'bg': const Color(0xFFFEE2E2),
    },
    {
      'title': 'Besar',
      'icon': Icons.date_range_rounded,
      'color': const Color(0xFF0D9488),
      'bg': const Color(0xFFCCFBF1),
    },
    {
      'title': 'Sakit',
      'icon': Icons.healing_rounded,
      'color': const Color(0xFFF59E0B),
      'bg': const Color(0xFFFEF3C7),
    },
    {
      'title': 'Melahirkan',
      'icon': Icons.child_friendly_rounded,
      'color': const Color(0xFF0284C7),
      'bg': const Color(0xFFE0F2FE),
    },
    {
      'title': 'Diluar\nTanggungan',
      'icon': Icons.person_off_rounded,
      'color': const Color(0xFF8B5CF6),
      'bg': const Color(0xFFEDE9FE),
    },
    {
      'title': 'Alasan\nPenting',
      'icon': Icons.priority_high_rounded,
      'color': const Color(0xFFEA580C),
      'bg': const Color(0xFFFFEDD5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return '-';
    }

    const List<String> namaBulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    String formatTgl(String dateStr) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = parts[2].padLeft(2, '0');
          final monthIndex = int.parse(parts[1]) - 1;
          if (monthIndex >= 0 && monthIndex < 12) {
            return '$day ${namaBulan[monthIndex]}';
          }
        }
        return dateStr;
      } catch (_) {
        return dateStr;
      }
    }

    return '${formatTgl(start)} s/d ${formatTgl(end)}';
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Ambil Profil User
      try {
        final userInfo = await _apiService.getUserInfo();
        final rawUser = userInfo['data'] ?? userInfo['user'] ?? userInfo;
        if (mounted) {
          setState(() {
            _userName = rawUser['nama'] ?? rawUser['name'] ?? 'Pegawai SIMPEG';
          });
        }
      } catch (e) {
        debugPrint('Gagal memuat profil: $e');
      }

      // 2. Ambil Data Dashboard
      final dashData = await _apiService.getDashboard();
      final cutiHariIni = dashData['data']?['cuti_hari_ini'] ?? {};

      if (mounted) {
        setState(() {
          _summaryCounts = {
            'Cuti Tahunan': cutiHariIni['jlh_cuti_tahunan'] ?? 0,
            'Cuti Besar': cutiHariIni['jlh_cuti_besar'] ?? 0,
            'Cuti Sakit': cutiHariIni['jlh_cuti_sakit'] ?? 0,
            'Cuti Melahirkan': cutiHariIni['jlh_cuti_melahirkan'] ?? 0,
            'Alasan Penting': cutiHariIni['jlh_cap'] ?? 0,
            'Diluar Tanggungan': cutiHariIni['jlh_cuti_diluartanggungan'] ?? 0,
          };
          _listPegawaiCuti = cutiHariIni['data'] as List<dynamic>? ?? [];
        });
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

  @override
  Widget build(BuildContext context) {
    final nip = context.watch<AuthProvider>().nip;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: kSimpegPurple,
          onRefresh: _loadAllData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(nip),
                const SizedBox(height: 20),
                _buildMenuKategoriGrid(),
                const SizedBox(height: 28),
                _buildSectionHeader('Jumlah yang Cuti Hari Ini'),
                const SizedBox(height: 12),
                _buildHorizontalSummary(),
                const SizedBox(height: 28),
                _buildSectionHeader('Daftar Pegawai Cuti Hari Ini'),
                const SizedBox(height: 12),
                _buildPegawaiSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? nip) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selamat Pagi,',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                _userName != 'Memuat Nama...' ? _userName : (nip ?? '-'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 28),
          color: const Color(0xFF334155),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMenuKategoriGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: _kategoriCuti.length,
        itemBuilder: (context, index) {
          final item = _kategoriCuti[index];
          final String title = item['title'] as String;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Navigasi ke FormPengajuanCutiScreen saat ikon diklik
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormPengajuanCutiScreen(
                    jenisCuti: 'Cuti ${title.replaceAll('\n', ' ')}',
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: item['bg'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildHorizontalSummary() {
    if (_isLoading) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _summaryCounts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPegawaiSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Gagal memuat data: $_errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_listPegawaiCuti.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Tidak ada pegawai yang cuti hari ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _listPegawaiCuti.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = _listPegawaiCuti[index];
        final String nama = item['nama'] ?? '-';
        final String jabatan = item['jabatan'] ?? item['bagian'] ?? '-';
        final String jenisCuti = item['jenis_cuti_text'] ?? 'Cuti Tahunan';
        final String lamaCuti = '${item['lama_cuti'] ?? '-'} Hari';
        final String rentangTanggal = _formatDateRange(
          item['start_date']?.toString(),
          item['end_date']?.toString(),
        );
        final String? foto = item['foto'];

        final String? fotoUrl = (foto != null && foto.isNotEmpty)
            ? '$_baseSikepFotoUrl/$foto'
            : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFE2E8F0),
                child: ClipOval(
                  child: fotoUrl != null
                      ? Image.network(
                          fotoUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Color(0xFF94A3B8),
                              size: 34,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFF94A3B8),
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nama,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lamaCuti,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            jabatan,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rentangTanggal,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EDFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        jenisCuti,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}