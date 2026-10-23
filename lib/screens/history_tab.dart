import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/api_service.dart';
import 'detail_cuti_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyList = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getHistoryCutiPersonal(page: 1);
      dynamic rawList;
      if (res['data'] is List) {
        rawList = res['data'];
      } else if (res['data'] is Map && res['data']['data'] is List) {
        rawList = res['data']['data'];
      } else if (res['list'] is List) {
        rawList = res['list'];
      }

      if (rawList != null && (rawList as List).isNotEmpty) {
        setState(() {
          _historyList = List<Map<String, dynamic>>.from(rawList);
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildStatusBadge(String statusText) {
    final lower = statusText.toLowerCase();

    Color bgColor;
    Color textColor;
    IconData icon;

    if (lower.contains('tolak')) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else if (lower.contains('selesai') || lower.contains('setuju')) {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    } else {
      bgColor = const Color(0xFFE0E7FF);
      textColor = const Color(0xFF4338CA);
      icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text(
          'History Cuti',
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
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSimpegPurple))
          : RefreshIndicator(
              color: kSimpegPurple,
              onRefresh: _fetchHistory,
              child: _historyList.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Belum ada riwayat cuti.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      itemCount: _historyList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = _historyList[index];
                        final jenisCuti = item['jenis_cuti_text'] ?? item['jenis_cuti'] ?? 'Cuti Tahunan';
                        final tglMulai = _formatDisplayDate(item['start_date']?.toString());
                        final tglSelesai = _formatDisplayDate(item['end_date']?.toString());
                        final statusText = item['proses_terakhir_cuti'] ??
                            item['proses_text'] ??
                            item['status_text'] ??
                            'Proses Selesai';
                        final tokenCuti = item['token_cuti']?.toString() ?? '';

                        final bool isRejected = statusText.toString().toLowerCase().contains('tolak');

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9),
                              width: isRejected ? 1.2 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
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
                                  ).then((_) => _fetchHistory());
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          jenisCuti,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (tokenCuti.isNotEmpty)
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatusBadge(statusText.toString()),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Mulai Cuti', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            const SizedBox(height: 4),
                                            Text(
                                              tglMulai,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Selesai Cuti', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            const SizedBox(height: 4),
                                            Text(
                                              tglSelesai,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}