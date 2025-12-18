import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? playerData;
  final bool isLoading;
  final Future<void> Function({bool silent}) onRefresh;

  const ProfileScreen({
    super.key,
    required this.playerData,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _sendingVerification = false;
  DateTime? _verificationEndTime;
  Timer? _countdownTimer;
  String _countdownText = "";

  final PageController _chartPageController = PageController(viewportFraction: 0.95);
  Timer? _chartScrollTimer;
  Timer? _chartPauseTimer;
  int _currentChartPage = 0;
  List<_GachaChartData> _parsedCharts = [];

  @override
  void initState() {
    super.initState();
    if (widget.playerData != null) {
      _parsedCharts = _parseGachaStats(widget.playerData!['statistic']);
      if (_parsedCharts.isNotEmpty) {
        _startChartAutoScroll();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerData != oldWidget.playerData) {
      final newCharts = _parseGachaStats(widget.playerData?['statistic']);
      if (newCharts.length != _parsedCharts.length) {
        setState(() {
          _parsedCharts = newCharts;
          _currentChartPage = 0;
        });
        if (_chartPageController.hasClients) {
          _chartPageController.jumpToPage(0);
        }
        _startChartAutoScroll();
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopChartAutoScroll();
    _chartPageController.dispose();
    super.dispose();
  }

  // --- CHART LOGIC ---
  void _startChartAutoScroll() {
    _stopChartAutoScroll();
    if (_parsedCharts.length > 1) {
      _chartScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && _chartPageController.hasClients) {
          int nextPage = _currentChartPage + 1;
          if (nextPage >= _parsedCharts.length) {
            nextPage = 0;
            _chartPageController.animateToPage(
              nextPage, 
              duration: const Duration(milliseconds: 800), 
              curve: Curves.fastOutSlowIn
            );
          } else {
            _chartPageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  void _stopChartAutoScroll() {
    _chartScrollTimer?.cancel();
    _chartPauseTimer?.cancel();
    _chartScrollTimer = null;
    _chartPauseTimer = null;
  }

  void _handleChartInteraction() {
    _chartScrollTimer?.cancel();
    _chartPauseTimer?.cancel();
    _chartPauseTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) _startChartAutoScroll();
    });
  }

  void _manualChartScroll(int direction) {
    _handleChartInteraction();
    if (!_chartPageController.hasClients) return;

    if (direction > 0) {
      if (_currentChartPage < _parsedCharts.length - 1) {
        _chartPageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _chartPageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    } else {
      if (_currentChartPage > 0) {
        _chartPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _chartPageController.animateToPage(_parsedCharts.length - 1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    }
  }

  List<_GachaChartData> _parseGachaStats(dynamic statisticRaw) {
    if (statisticRaw == null) return [];
    final Map<String, dynamic> stats = Map<String, dynamic>.from(statisticRaw);

    if (!stats.containsKey('pull') && !stats.keys.any((k) => k.startsWith('pull.'))) {
      return [];
    }

    final Map<int, int> overallRarityMap = {};
    final Map<String, Map<int, int>> bannerRarityMap = {};
    int overallTotal = 0;

    stats.forEach((key, value) {
      final valInt = int.tryParse(value.toString()) ?? 0;
      if (valInt == 0) return;
      final parts = key.split('.');
      
      if (parts.length == 3 && parts[0] == 'pull' && parts[1] == 'rarity') {
        final rarity = int.tryParse(parts[2]);
        if (rarity != null) {
          overallRarityMap[rarity] = (overallRarityMap[rarity] ?? 0) + valInt;
          overallTotal += valInt;
        }
      } else if (parts.length == 4 && parts[0] == 'pull' && parts[2] == 'rarity') {
        final bannerId = parts[1];
        final rarity = int.tryParse(parts[3]);
        if (rarity != null) {
          if (!bannerRarityMap.containsKey(bannerId)) {
            bannerRarityMap[bannerId] = {};
          }
          bannerRarityMap[bannerId]![rarity] = (bannerRarityMap[bannerId]![rarity] ?? 0) + valInt;
        }
      }
    });

    List<_GachaChartData> results = [];
    if (overallRarityMap.isNotEmpty) {
      results.add(_GachaChartData(title: "Overall Performance", total: overallTotal, rarityCounts: overallRarityMap));
    }
    bannerRarityMap.forEach((bannerId, rarityMap) {
      int bannerTotal = rarityMap.values.fold(0, (sum, count) => sum + count);
      String title = "${bannerId[0].toUpperCase()}${bannerId.substring(1)} Banner";
      results.add(_GachaChartData(title: title, total: bannerTotal, rarityCounts: rarityMap));
    });

    return results;
  }

  // --- VERIFICATION LOGIC ---
  Future<void> _requestVerification() async {
    if (_sendingVerification) return;
    setState(() => _sendingVerification = true);
    try {
      final res = await Api.request("/mail/validate", method: "POST");
      if (mounted && res != null && res['expireTime'] != null) {
        _startCooldown(DateTime.parse(res['expireTime']).toLocal());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification email sent!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  void _startCooldown(DateTime expireTime) {
    _verificationEndTime = expireTime;
    _updateCountdown();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateCountdown(); else timer.cancel();
    });
  }

  void _updateCountdown() {
    if (_verificationEndTime == null) return;
    final diff = _verificationEndTime!.difference(DateTime.now());
    setState(() {
      if (diff.isNegative) {
        _countdownTimer?.cancel();
        _verificationEndTime = null;
        _countdownText = "";
      } else {
        _countdownText = "${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (widget.isLoading && widget.playerData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.playerData == null) {
      return Center(
        child: ElevatedButton(onPressed: () => widget.onRefresh(), child: const Text("Retry"))
      );
    }

    final data = widget.playerData!;
    final currency = data['currency'] ?? {};
    final stats = Map<String, dynamic>.from(data['statistic'] ?? {});
    
    final genericStats = Map<String, dynamic>.from(stats);
    genericStats.removeWhere((key, value) => 
      ['last_seen', 'register_date', 'highest_tower_floor'].contains(key) || key.startsWith('pull')
    );

    final displayName = data['displayName'] ?? data['username'] ?? "Unknown";
    final isVerified = data['emailVerified'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                CircleAvatar(radius: 32, backgroundColor: AppColors.accent, child: Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.white))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (isVerified) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18)]
                      ]),
                      const SizedBox(height: 4),
                      if (data['email'] != null) Text(data['email'], style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white24), onPressed: () => widget.onRefresh())
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // --- CURRENCY ROW ---
          if (!isMobile) ...[
            Row(
              children: [
                Expanded(child: _buildCurrencyCard("Gems", currency['gem'] ?? 0, Icons.diamond, const Color(0xFF29B6F6))),
                const SizedBox(width: 16),
                Expanded(child: _buildCurrencyCard("Coins", currency['coin'] ?? 0, Icons.monetization_on, const Color(0xFFFFCA28))),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // --- GACHA CHARTS CAROUSEL ---
          if (_parsedCharts.isNotEmpty) ...[
            const Text("PULL HISTORY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Listener(
                    onPointerDown: (_) => _handleChartInteraction(),
                    child: PageView.builder(
                      controller: _chartPageController,
                      itemCount: _parsedCharts.length,
                      onPageChanged: (index) {
                        setState(() => _currentChartPage = index);
                      },
                      itemBuilder: (context, index) {
                        return _GachaChartCard(data: _parsedCharts[index]);
                      },
                    ),
                  ),
                  
                  if (_parsedCharts.length > 1) ...[
                    Positioned(
                      left: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white24, size: 20),
                        onPressed: () => _manualChartScroll(-1),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 20),
                        onPressed: () => _manualChartScroll(1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            if (_parsedCharts.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_parsedCharts.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentChartPage == index ? AppColors.accent : Colors.white24,
                      ),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // STATISTICS TABLE
          const Text("STATISTICS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: genericStats.isEmpty 
              ? const Center(child: Text("No data", style: TextStyle(color: Colors.grey)))
              : Column(
                  children: genericStats.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatKey(entry.key), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        Text("${entry.value}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )).toList(),
                ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildCurrencyCard(String label, num value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12))]),
          const SizedBox(height: 8),
          Text("$value", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatKey(String key) => key.replaceAll("_", " ").split(" ").map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1).toLowerCase() : "").join(" ");
}

// --- CHART CLASSES ---
class _GachaChartData {
  final String title;
  final int total;
  final Map<int, int> rarityCounts;
  _GachaChartData({required this.title, required this.total, required this.rarityCounts});
}

class _GachaChartCard extends StatelessWidget {
  final _GachaChartData data;
  const _GachaChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = data.rarityCounts.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(size: const Size(140, 140), painter: _PieChartPainter(data.rarityCounts, data.total)),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${data.total}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Text("Pulls", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: sortedEntries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.getRarityColor(entry.key), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(AppColors.getRarityLabel(entry.key), style: const TextStyle(fontSize: 11, color: AppColors.textDim))),
                              Text("${entry.value} (${(entry.value / data.total * 100).toStringAsFixed(1)}%)", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<int, int> data;
  final int total;
  _PieChartPainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.3;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    double startAngle = -pi / 2;
    
    final sortedKeys = data.keys.toList()..sort();
    for (var key in sortedKeys) {
      final sweepAngle = (data[key]! / total) * 2 * pi;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = AppColors.getRarityColor(key);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}