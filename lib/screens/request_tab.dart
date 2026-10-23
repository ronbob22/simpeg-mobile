import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';
import 'detail_cuti_screen.dart';

class VerifierRoleData {
  final int id;
  final String title;
  final List<dynamic> requests;

  VerifierRoleData({
    required this.id,
    required this.title,
    required this.requests,
  });
}

class RequestTab extends StatefulWidget {
  const RequestTab({super.key});

  @override
  State<RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends State<RequestTab> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  TabController? _tabController;
  bool _isLoading = true;
  String _currentLoginNip = '';

  List<Map<String, dynamic>> _personalCutiList = [];
  List<VerifierRoleData> _verifierTabs = [];

  static const String _baseSikepFotoUrl =
      'https://sikep.mahkamahagung.go.id/uploads/foto_pegawai';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final s = val.toString().replaceAll(' ', 'T');
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  bool _isRejected(Map<String, dynamic> data) {
    final statusStr = (data['proses_terakhir_cuti'] ?? data['proses_text'] ?? data['status_cuti'] ?? '')
        .toString()
        .toLowerCase();
    return statusStr.contains('tolak') || statusStr.contains('batal') || statusStr.contains('reject');
  }

  int _rejectedStage(Map<String, dynamic> data) {
    final statusStr = (data['proses_terakhir_cuti'] ?? data['proses_text'] ?? '')
        .toString()
        .toLowerCase();

    final bool hasPejabat = data['pejabat_sign_at'] != null &&
        data['pejabat_sign_at'].toString().isNotEmpty &&
        data['pejabat_sign_at'] != 'null';

    final bool hasAtasan = data['atasan_langsung_sign_at'] != null &&
        data['atasan_langsung_sign_at'].toString().isNotEmpty &&
        data['atasan_langsung_sign_at'] != 'null';

    if (hasPejabat || statusStr.contains('pejabat')) {
      return 3;
    } else if (hasAtasan || statusStr.contains('atasan')) {
      return 2;
    } else {
      return 1;
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    String loginNip = '';
    String jabatanUser = '';
    try {
      final userRes = await _apiService.getUserInfo();
      final userData = userRes['data'] ?? userRes['user'] ?? userRes;
      loginNip = (userData['nip'] ?? '').toString();
      jabatanUser = (userData['jabatan'] ?? userData['bagian'] ?? '').toString().toLowerCase();
    } catch (_) {}

    final bool isPejabatOrKetua = jabatanUser.contains('ketua') ||
        jabatanUser.contains('pejabat') ||
        jabatanUser.contains('wakil') ||
        jabatanUser.contains('hakim');

    // 1. Antrean Verifikasi untuk Role Atasan/Pejabat/UP
    List<dynamic> listTahap1 = [];
    List<dynamic> listTahap2 = [];
    List<dynamic> listTahap3 = [];
    List<dynamic> listCancel = [];
    bool canAccessTahap1 = false;
    bool canAccessTahap2 = false;
    bool canAccessTahap3 = false;

    try {
      final r1 = await _apiService.getListPermohonanCuti(tahapanId: 1);
      if (r1['status'] == true) {
        canAccessTahap1 = true;
        listTahap1 = (r1['data_permohonan'] ?? r1['data'] ?? []) as List<dynamic>;
      }
    } catch (_) {}

    try {
      final r2 = await _apiService.getListPermohonanCuti(tahapanId: 2);
      if (r2['status'] == true) {
        canAccessTahap2 = true;
        listTahap2 = (r2['data_permohonan'] ?? r2['data'] ?? []) as List<dynamic>;
      }
    } catch (_) {}

    try {
      final r3 = await _apiService.getListPermohonanCuti(tahapanId: 3);
      if (r3['status'] == true) {
        canAccessTahap3 = true;
        listTahap3 = (r3['data_permohonan'] ?? r3['data'] ?? []) as List<dynamic>;
      }
    } catch (_) {}

    // Cek daftar permohonan pembatalan cuti untuk Kepegawaian (UP)
    if (canAccessTahap1) {
      try {
        final rCancel = await _apiService.getListAskCancel();
        if (rCancel['status'] == true) {
          listCancel = (rCancel['data_permohonan'] ?? rCancel['data'] ?? rCancel['list'] ?? []) as List<dynamic>;
        }
      } catch (_) {}
    }

    List<VerifierRoleData> detectedTabs = [];

    if (canAccessTahap3 || isPejabatOrKetua) {
      List<dynamic> pejabatItems = listTahap3;
      if (pejabatItems.isEmpty && isPejabatOrKetua && listTahap2.isNotEmpty) {
        pejabatItems = listTahap2;
      }

      detectedTabs.add(
        VerifierRoleData(
          id: 3,
          title: 'Confirm Pejabat',
          requests: pejabatItems,
        ),
      );
    }

    if (canAccessTahap2) {
      detectedTabs.add(
        VerifierRoleData(
          id: 2,
          title: 'Confirm Atasan',
          requests: listTahap2,
        ),
      );
    }

    if (canAccessTahap1) {
      detectedTabs.add(
        VerifierRoleData(
          id: 1,
          title: 'Confirm Kepegawaian',
          requests: listTahap1,
        ),
      );

      if (listCancel.isNotEmpty) {
        detectedTabs.add(
          VerifierRoleData(
            id: 99,
            title: 'Batal Cuti',
            requests: listCancel,
          ),
        );
      }
    }

    // 2. Ambil data draft lokal milik user
    final prefs = await SharedPreferences.getInstance();
    final key = 'active_permohonan_$loginNip';
    final savedStr = prefs.getString(key);

    List<dynamic> localRawList = [];
    if (savedStr != null && savedStr.isNotEmpty) {
      try {
        localRawList = jsonDecode(savedStr) as List<dynamic>;
      } catch (_) {}
    }

    final now = DateTime.now();
    List<Map<String, dynamic>> activeDrafts = [];

    for (var item in localRawList) {
      if (item is! Map) continue;
      Map<String, dynamic> draft = Map<String, dynamic>.from(item);
      final String token = draft['token_cuti']?.toString() ?? '';

      if (token.isNotEmpty) {
        try {
          final detailRes = await _apiService.getDetilCuti(token);
          Map<String, dynamic>? freshData;
          if (detailRes['data'] is Map && detailRes['data']['data'] is Map) {
            freshData = detailRes['data']['data'] as Map<String, dynamic>;
          } else if (detailRes['data'] is Map) {
            freshData = detailRes['data'] as Map<String, dynamic>;
          }

          if (freshData != null) {
            draft['up_sign_at'] = freshData['up_sign_at'];
            draft['atasan_langsung_sign_at'] = freshData['atasan_langsung_sign_at'];
            draft['pejabat_sign_at'] = freshData['pejabat_sign_at'];
            draft['proses_id'] = freshData['proses_id'];
            draft['proses_terakhir_cuti'] = freshData['proses_text'] ?? freshData['status_text'] ?? draft['proses_terakhir_cuti'];
            draft['proses_text'] = freshData['proses_text'] ?? freshData['status_text'];
            draft['status_cuti'] = freshData['status_cuti'] ?? freshData['status'];
            draft['catatan_up'] = freshData['catatan_up'];
            draft['catatan_atasan_langsung'] = freshData['catatan_atasan_langsung'];
            draft['catatan_pejabat'] = freshData['catatan_pejabat'];
          }
        } catch (_) {}
      }

      final bool isSelesai = (draft['pejabat_sign_at'] != null &&
              draft['pejabat_sign_at'].toString().isNotEmpty &&
              draft['pejabat_sign_at'] != 'null') ||
          (draft['proses_terakhir_cuti']?.toString().toLowerCase().contains('selesai') ?? false);

      final bool isDitolak = _isRejected(draft);

      if (isSelesai || isDitolak) {
        DateTime tglEvent = _parseDateTime(
          draft['pejabat_sign_at'] ??
              draft['atasan_langsung_sign_at'] ??
              draft['up_sign_at'] ??
              draft['created_at'],
        );
        if (tglEvent.millisecondsSinceEpoch > 0 && now.difference(tglEvent).inHours >= 48) {
          continue;
        }
      }

      activeDrafts.add(draft);
    }

    await prefs.setString(key, jsonEncode(activeDrafts));

    // 3. Ambil riwayat dari server
    List<Map<String, dynamic>> serverHistory = [];
    try {
      final resHistory = await _apiService.getHistoryCutiPersonal(page: 1);
      dynamic rawList;
      if (resHistory['data'] is List) {
        rawList = resHistory['data'];
      } else if (resHistory['data'] is Map && resHistory['data']['data'] is List) {
        rawList = resHistory['data']['data'];
      } else if (resHistory['list'] is List) {
        rawList = resHistory['list'];
      }

      if (rawList != null && (rawList as List).isNotEmpty) {
        serverHistory = List<Map<String, dynamic>>.from(rawList);
      }
    } catch (_) {}

    // 4. Penggabungan Data Tanpa Menghilangkan Pengajuan Baru
    List<Map<String, dynamic>> combinedList = List.from(activeDrafts);

    for (var srvItem in serverHistory) {
      final srv = Map<String, dynamic>.from(srvItem);
      final String srvToken = srv['token_cuti']?.toString() ?? '';
      final String srvStart = (srv['start_date'] ?? '').toString().trim().split(' ')[0];
      final String srvEnd = (srv['end_date'] ?? '').toString().trim().split(' ')[0];
      final String srvStatus = (srv['proses_terakhir_cuti'] ?? srv['proses_text'] ?? '').toString().toLowerCase();

      final bool isSelesai = srvStatus.contains('selesai') && (srv['pejabat_sign_at'] != null);
      final bool isDitolak = _isRejected(srv);

      if (isSelesai || isDitolak) {
        DateTime tglEvent = _parseDateTime(
          srv['pejabat_sign_at'] ??
              srv['atasan_langsung_sign_at'] ??
              srv['up_sign_at'] ??
              srv['created_at'],
        );
        if (tglEvent.millisecondsSinceEpoch > 0 && now.difference(tglEvent).inHours >= 48) {
          continue;
        }
      }

      bool alreadyExists = combinedList.any((local) {
        final localToken = local['token_cuti']?.toString() ?? '';
        if (srvToken.isNotEmpty && localToken.isNotEmpty) {
          return srvToken == localToken;
        }
        final localStart = (local['start_date'] ?? '').toString().trim().split(' ')[0];
        final localEnd = (local['end_date'] ?? '').toString().trim().split(' ')[0];
        return (localStart == srvStart && localEnd == srvEnd && _isRejected(local) == isDitolak);
      });

      if (!alreadyExists) {
        combinedList.add(srv);
      }
    }

    // 5. PENGURUTAN:
    // Pengajuan aktif (sedang berproses) diposisikan di paling atas, 
    // disusul dengan urutan kronologis data terbaru.
    combinedList.sort((a, b) {
      final bool aActive = !_isRejected(a) && (a['pejabat_sign_at'] == null);
      final bool bActive = !_isRejected(b) && (b['pejabat_sign_at'] == null);

      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;

      DateTime timeA = _parseDateTime(a['created_at']);
      DateTime timeB = _parseDateTime(b['created_at']);

      if (timeA.millisecondsSinceEpoch == 0) timeA = _parseDateTime(a['start_date']);
      if (timeB.millisecondsSinceEpoch == 0) timeB = _parseDateTime(b['start_date']);

      return timeB.compareTo(timeA);
    });

    if (mounted) {
      final totalTabs = 1 + detectedTabs.length;

      int initialIndex = 0;
      for (int i = 0; i < detectedTabs.length; i++) {
        if (detectedTabs[i].requests.isNotEmpty) {
          initialIndex = i + 1;
          break;
        }
      }

      _tabController?.dispose();
      if (totalTabs > 1) {
        _tabController = TabController(
          length: totalTabs,
          vsync: this,
          initialIndex: initialIndex,
        );
      } else {
        _tabController = null;
      }

      setState(() {
        _currentLoginNip = loginNip;
        _verifierTabs = detectedTabs;
        _personalCutiList = combinedList;
        _isLoading = false;
      });
    }
  }

  String _formatDisplayDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    try {
      final clean = raw.trim().split(' ')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[2]);
        final m = int.parse(parts[1]) - 1;
        final y = parts[0];
        if (m >= 0 && m < 12) return '$d ${bulan[m]} $y';
      }
      return raw;
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleTabs = _verifierTabs.isNotEmpty && _tabController != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'Permohonan Cuti',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            color: const Color(0xFF334155),
            onPressed: _fetchData,
          ),
        ],
        bottom: hasMultipleTabs
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: kSimpegPurple,
                indicatorWeight: 3,
                labelColor: kSimpegPurple,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                tabs: [
                  const Tab(text: 'Personal'),
                  ..._verifierTabs.map(
                    (tab) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab.title),
                          if (tab.requests.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${tab.requests.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSimpegPurple))
          : RefreshIndicator(
              color: kSimpegPurple,
              onRefresh: _fetchData,
              child: hasMultipleTabs
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPersonalView(),
                        ..._verifierTabs.map((tab) => _buildConfirmView(tab.requests)),
                      ],
                    )
                  : _buildPersonalView(),
            ),
    );
  }

  Widget _buildPersonalView() {
    if (_personalCutiList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Center(
            child: Text(
              'Belum ada permohonan cuti yang aktif.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _personalCutiList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final data = _personalCutiList[index];
        final jenisCuti = data['jenis_cuti_text'] ?? data['jenis_cuti'] ?? 'Cuti Tahunan';
        final tglMulai = _formatDisplayDate(data['start_date']?.toString());
        final tglSelesai = _formatDisplayDate(data['end_date']?.toString());
        final tokenCuti = data['token_cuti']?.toString() ?? '';

        final bool isRejected = _isRejected(data);
        final int rejStage = _rejectedStage(data);

        final bool hasUpSign = data['up_sign_at'] != null &&
            data['up_sign_at'].toString().isNotEmpty &&
            data['up_sign_at'] != 'null';

        final bool hasAtasanSign = data['atasan_langsung_sign_at'] != null &&
            data['atasan_langsung_sign_at'].toString().isNotEmpty &&
            data['atasan_langsung_sign_at'] != 'null';

        final bool hasPejabatSign = data['pejabat_sign_at'] != null &&
            data['pejabat_sign_at'].toString().isNotEmpty &&
            data['pejabat_sign_at'] != 'null';

        final Color cardBg = isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
        final Color cardBorder = isRejected ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
        final Color cardTitle = isRejected ? const Color(0xFF991B1B) : const Color(0xFF065F46);
        final Color cardLabel = isRejected ? const Color(0xFFB91C1C) : const Color(0xFF047857);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (tokenCuti.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailCutiScreen(tokenCuti: tokenCuti),
                  ),
                ).then((_) => _fetchData());
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            jenisCuti,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cardTitle,
                            ),
                          ),
                          if (isRejected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'DITOLAK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (tokenCuti.isNotEmpty)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isRejected ? const Color(0xFFEF4444) : const Color(0xFF059669),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Alur Progres Dinamis
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepNode(
                        'Pengajuan',
                        isPassed: true,
                        isRejected: false,
                      ),
                      _buildStepLine(
                        isPassed: hasUpSign || (isRejected && rejStage >= 1),
                        isRejected: isRejected && rejStage == 1,
                      ),
                      _buildStepNode(
                        isRejected && rejStage == 1 ? 'Ditolak\nUP' : 'UP',
                        isPassed: hasUpSign && (!isRejected || rejStage > 1),
                        isRejected: isRejected && rejStage == 1,
                      ),
                      _buildStepLine(
                        isPassed: (hasAtasanSign && !isRejected) || (isRejected && rejStage >= 2),
                        isRejected: isRejected && rejStage == 2,
                      ),
                      _buildStepNode(
                        isRejected && rejStage == 2 ? 'Ditolak\nAtasan' : 'Verifikasi\nAtasan',
                        isPassed: hasAtasanSign && (!isRejected || rejStage > 2),
                        isRejected: isRejected && rejStage == 2,
                      ),
                      _buildStepLine(
                        isPassed: hasPejabatSign && !isRejected,
                        isRejected: isRejected && rejStage == 3,
                      ),
                      _buildStepNode(
                        isRejected && rejStage == 3 ? 'Ditolak\nPejabat' : 'Verifikasi\nPejabat',
                        isPassed: hasPejabatSign && !isRejected,
                        isRejected: isRejected && rejStage == 3,
                      ),
                      _buildStepLine(
                        isPassed: hasPejabatSign && !isRejected,
                        isRejected: false,
                      ),
                      _buildStepNode(
                        'Selesai',
                        isPassed: hasPejabatSign && !isRejected,
                        isRejected: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mulai Cuti', style: TextStyle(fontSize: 12, color: cardLabel)),
                          const SizedBox(height: 4),
                          Text(
                            tglMulai,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cardTitle),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Selesai Cuti', style: TextStyle(fontSize: 12, color: cardLabel)),
                          const SizedBox(height: 4),
                          Text(
                            tglSelesai,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cardTitle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmView(List<dynamic> requestList) {
    if (requestList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Center(
            child: Text(
              'Tidak ada permohonan yang perlu diverifikasi.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: requestList.length,
      itemBuilder: (context, index) {
        final item = requestList[index] as Map<String, dynamic>;

        final String nama = item['nama'] ?? item['nama_pegawai'] ?? 'Pegawai';
        final String nip = item['nip'] ?? '-';
        final String jenisCuti = item['jenis_cuti_text'] ?? item['jenis_cuti'] ?? 'Cuti Tahunan';
        final String tglMulai = _formatDisplayDate(item['start_date']?.toString());
        final String tglSelesai = _formatDisplayDate(item['end_date']?.toString());
        final String lamaCuti = '${item['lamanya_cuti'] ?? item['lama_cuti'] ?? '-'} hari';
        final String? foto = item['foto'];
        final String tokenCuti = item['token_cuti']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (tokenCuti.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailCutiScreen(tokenCuti: tokenCuti),
                    ),
                  ).then((_) => _fetchData());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token cuti tidak ditemukan')),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 26, color: Color(0xFF94A3B8)),
                                  )
                                : const Icon(Icons.person, size: 26, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text('NIP: $nip', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jenis Cuti', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text(jenisCuti, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tanggal Cuti', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text('$tglMulai - $tglSelesai', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lama Cuti', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text(lamaCuti, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepNode(String label, {required bool isPassed, required bool isRejected}) {
    Color nodeColor;
    Widget? innerIcon;

    if (isRejected) {
      nodeColor = const Color(0xFFEF4444);
      innerIcon = const Icon(Icons.close_rounded, size: 12, color: Colors.white);
    } else if (isPassed) {
      nodeColor = const Color(0xFF10B981);
    } else {
      nodeColor = const Color(0xFFCBD5E1);
    }

    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: nodeColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: isRejected
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(child: innerIcon),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: (isPassed || isRejected) ? FontWeight.bold : FontWeight.w500,
            color: isRejected
                ? const Color(0xFFDC2626)
                : (isPassed ? const Color(0xFF065F46) : const Color(0xFF64748B)),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isPassed, required bool isRejected}) {
    Color lineColor;
    if (isRejected) {
      lineColor = const Color(0xFFF87171);
    } else if (isPassed) {
      lineColor = const Color(0xFF10B981);
    } else {
      lineColor = const Color(0xFFE2E8F0);
    }

    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 18),
        color: lineColor,
      ),
    );
  }
}