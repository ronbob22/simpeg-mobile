import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';

class SaldoTab extends StatefulWidget {
  const SaldoTab({super.key});

  @override
  State<SaldoTab> createState() => _SaldoTabState();
}

class _SaldoTabState extends State<SaldoTab> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Nilai saldo cuti pribadi
  int _sisaTahunIni = 0;
  int _sisaTahunLalu = 0;
  int _sisaCutiSakit = 0;
  int _saldoTertahan = 0;

  // Pencarian saldo pegawai lain
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchPegawaiResult = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  static const String _baseSikepFotoUrl =
      'https://sikep.mahkamahagung.go.id/uploads/foto_pegawai';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSaldo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _parseToInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<void> _loadSaldo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getSaldoCuti();

      Map<String, dynamic> data = {};
      if (res['data'] is Map<String, dynamic>) {
        data = res['data'] as Map<String, dynamic>;
      } else if (res['data'] is List && (res['data'] as List).isNotEmpty) {
        if (res['data'][0] is Map<String, dynamic>) {
          data = res['data'][0] as Map<String, dynamic>;
        }
      } else if (res is Map<String, dynamic>) {
        data = res;
      }

      if (mounted) {
        setState(() {
          _sisaTahunIni = _parseToInt(data['sisa_tahun_ini'] ?? data['sisa_n']);
          _sisaTahunLalu = _parseToInt(data['sisa_tahun_lalu'] ?? data['sisa_n_1']);
          _sisaCutiSakit = _parseToInt(data['sisa_cuti_sakit']);
          _saldoTertahan = _parseToInt(data['saldo_tertahan'] ?? data['tertahan']);
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

  Future<void> _cariSaldoPegawai(String query) async {
    if (query.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final res = await _apiService.searchSaldoNama(query.trim());
      dynamic rawData = res['data'] ?? res['list'] ?? res['data_pegawai'];

      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map) {
        list = [rawData];
      }

      if (mounted) {
        setState(() => _searchPegawaiResult = list);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _searchPegawaiResult = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'Saldo Cuti',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kSimpegPurple,
          indicatorWeight: 3,
          labelColor: kSimpegPurple,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Cuti Anda'),
            Tab(text: 'Cuti Pegawai'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            color: kSimpegPurple,
            onRefresh: _loadSaldo,
            child: _buildCutiAndaView(),
          ),
          _buildCutiPegawaiView(),
        ],
      ),
    );
  }

  Widget _buildCutiAndaView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kSimpegPurple),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gagal memuat saldo: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSaldo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSimpegPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSolidGridCard(
                title: 'Sisa tahun ini',
                value: '$_sisaTahunIni',
                backgroundColor: const Color(0xFF14B8A6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSolidGridCard(
                title: 'Sisa tahun lalu',
                value: '$_sisaTahunLalu',
                backgroundColor: const Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildSolidGridCard(
                title: 'Sisa Cuti Sakit',
                value: '$_sisaCutiSakit',
                backgroundColor: const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSolidGridCard(
                title: 'Saldo Tertahan',
                value: '$_saldoTertahan',
                backgroundColor: const Color(0xFFA855F7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFD97706),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Perhatian !!!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ajukan penangguhan cuti bila saldo cuti tahun ini lebih dari 6 hari',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB45309),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSolidGridCard({
    required String title,
    required String value,
    required Color backgroundColor,
  }) {
    return Container(
      height: 125,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'hari',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCutiPegawaiView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _cariSaldoPegawai,
          decoration: InputDecoration(
            hintText: 'Cari nama pegawai...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: kSimpegPurple),
              onPressed: () => _cariSaldoPegawai(_searchController.text),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: kSimpegPurple),
            ),
          )
        else if (_hasSearched && _searchPegawaiResult.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Column(
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text(
                  'Pegawai tidak ditemukan.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ],
            ),
          )
        else if (!_hasSearched)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Column(
              children: [
                Icon(Icons.person_search_rounded, size: 48, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text(
                  'Ketikkan nama pegawai untuk melihat informasi saldo cuti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          )
        else
          ..._searchPegawaiResult.map((pegawai) {
            final String nama = pegawai['nama'] ?? pegawai['name'] ?? '-';
            final String nip = pegawai['nip'] ?? '-';
            final String jabatan = pegawai['jabatan'] ?? pegawai['bagian'] ?? '-';
            final String? foto = pegawai['foto'];

            final sisaTahunIni = _parseToInt(pegawai['sisa_tahun_ini'] ?? pegawai['sisa_n']);
            final sisaTahunLalu = _parseToInt(pegawai['sisa_tahun_lalu'] ?? pegawai['sisa_n_1']);
            final sisaSakit = _parseToInt(pegawai['sisa_cuti_sakit']);
            final tertahan = _parseToInt(pegawai['saldo_tertahan'] ?? pegawai['tertahan']);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: ClipOval(
                          child: (foto != null && foto.isNotEmpty)
                              ? Image.network(
                                  '$_baseSikepFotoUrl/$foto',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 26,
                                    color: Color(0xFF94A3B8),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 26,
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
                              nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIP: $nip',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if (jabatan != '-') ...[
                              const SizedBox(height: 2),
                              Text(
                                jabatan,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniSaldoChip(
                          label: 'Thn Ini',
                          val: '$sisaTahunIni hari',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniSaldoChip(
                          label: 'Thn Lalu',
                          val: '$sisaTahunLalu hari',
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniSaldoChip(
                          label: 'Sakit',
                          val: '$sisaSakit hari',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniSaldoChip(
                          label: 'Tertahan',
                          val: '$tertahan hari',
                          color: const Color(0xFFA855F7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMiniSaldoChip({
    required String label,
    required String val,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}