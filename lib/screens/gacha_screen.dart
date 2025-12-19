import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';
import '../widgets/hero_card.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with TickerProviderStateMixin {
  // --- Original State Variables ---
  List<dynamic> banners = [];
  bool bannersLoading = false;
  List<dynamic> pullResults = [];

  int? _activePullCount; 
  static const int _kInfiniteStart = 1000;
  int _currentRealIndex = 0;
  late PageController _bannerController;
  Timer? _autoSlideTimer;
  Timer? _pauseTimer;
  Timer? _refreshTimer;

  // --- Animation & Store State ---
  List<dynamic> _overlayQueue = []; 
  Map<String, dynamic>? _currentOverlayHero; 
  late AnimationController _overlayController;
  late Animation<double> _scaleAnimation;

  final List<Map<String, dynamic>> _storeItems = List.generate(8, (index) => {
    "name": "Pack ${index + 1}",
    "price": "\$${(index + 1) * 4 + 0.99}",
    "gems": (index + 1) * 500,
    "color": Colors.primaries[index % Colors.primaries.length],
  });

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 800)
    );
    _scaleAnimation = CurvedAnimation(parent: _overlayController, curve: Curves.elasticOut);

    _bannerController = PageController(viewportFraction: 0.9, initialPage: _kInfiniteStart);
    _loadBanners();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _loadBanners(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stopAutoSlide();
    _bannerController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  // --- Original Banner Logic (Strictly Preserved) ---
  Future<void> _loadBanners({bool silent = false}) async {
    if (bannersLoading) return;
    if (!silent) setState(() => bannersLoading = true);

    try {
      final res = await Api.request("/gacha/banners");
      if (mounted) {
        setState(() {
            bannersLoading = false;
            if (res['data'] != null && res['data'] is List) {
              final newBanners = res['data'];

              bool hasChanged = banners.length != newBanners.length;
              if (!hasChanged && banners.isNotEmpty && newBanners.isNotEmpty) {
                hasChanged = banners[0]['id'] != newBanners[0]['id'];
              }

              if (hasChanged || banners.isEmpty) {
                banners = newBanners;
                if (banners.isNotEmpty && !_bannerController.hasClients) {
                  _bannerController.dispose(); 
                  int mid = _kInfiniteStart;
                  int zeroIndexPage = mid - (mid % banners.length);
                  _bannerController = PageController(viewportFraction: 0.9, initialPage: zeroIndexPage);
                }
                if (!silent) _startAutoSlide();
              }
            }
          }
        );
      }
    }
    catch (e) {
      if (mounted) setState(() => bannersLoading = false);
    }
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    if (banners.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          if (mounted && _bannerController.hasClients) {
            _bannerController.nextPage(
              duration: const Duration(milliseconds: 500), 
              curve: Curves.easeInOut
            );
          }
        }
      );
    }
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _pauseTimer?.cancel();
    _autoSlideTimer = null;
    _pauseTimer = null;
  }

  void _handleUserInteraction() {
    _autoSlideTimer?.cancel();
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) _startAutoSlide();
      }
    );
  }

  void _scrollBanner(int direction) {
    _handleUserInteraction();
    if (direction > 0) {
      _bannerController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    else {
      _bannerController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // --- Pull Logic ---
  Future<void> _pull(int count) async {
    _handleUserInteraction();
    if (banners.isEmpty || _activePullCount != null) return;
    setState(() => _activePullCount = count);

    try {
      final bannerId = banners[_currentRealIndex]['id'];
      final res = await Api.request("/gacha/pull", method: "POST", body: {"bannerId": bannerId, "count": count});

      if (mounted) {
        if (res['data'] != null && res['data']['result'] != null) {
          final results = res['data']['result'] as List;
          setState(() {
            pullResults = results;
            _overlayQueue = results.where((h) => (h['rarity'] ?? 0) >= 6).toList();
          });
          if (_overlayQueue.isNotEmpty) {
            _showNextOverlay();
          }
        }
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? "Pull failed: ${res['error']}"), backgroundColor: Colors.redAccent)
          );
        }
      }
    }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network Error"), backgroundColor: Colors.redAccent)
        );
      }
    }
    finally {
      if (mounted) {
        setState(() => _activePullCount = null);
      }
    }
  }

  void _showNextOverlay() {
    if (_overlayQueue.isNotEmpty) {
      setState(() {
        _currentOverlayHero = _overlayQueue.removeAt(0);
      });
      _overlayController.forward(from: 0.0);
    } else {
      setState(() {
        _currentOverlayHero = null;
      });
    }
  }

  Future<void> _renameHero(String cid, String newName) async {
    final res = await Api.request("/roster/rename", method: "POST", body: {"cid": cid, "name": newName});
    if (res['status'] == 200) {
      setState(() {
          pullResults = pullResults.map((h) => h['cid'] == cid ? {...h, 'displayName': newName} : h).toList();
        }
      );
    }
  }

  Map<String, dynamic> _getCurrencyDetails(Map<String, dynamic> bannerData) {
    final Map<String, dynamic> currency = bannerData['currency'] ?? {};
    if (currency.containsKey('gem')) {
      return {'cost': currency['gem'] ?? 0, 'icon': AppIcons.gem, 'color': AppColors.gem, 'type': 'Gem'};
    } else {
      return {'cost': currency['coin'] ?? 0, 'icon': AppIcons.coin, 'color': AppColors.coin, 'type': 'Coin'};
    }
  }

  void _showRateInfo(Map<String, dynamic> rawRates) {
    _stopAutoSlide();
    double totalWeight = 0.0;
    rawRates.forEach((k, v) => totalWeight += (v as num).toDouble());
    List<int> sortedRarities = rawRates.keys.map((k) => int.parse(k)).toList()..sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Drop Rates", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sortedRarities.length,
            separatorBuilder: (_, __) => const Divider(height: 8, color: Colors.white10),
            itemBuilder: (context, index) {
              int r = sortedRarities[index];
              double weight = (rawRates[r.toString()] as num).toDouble();
              double percentage = totalWeight > 0 ? (weight / totalWeight * 100) : 0;
              if (weight <= 0) return const SizedBox.shrink();
              return Row(
                children: [
                  RarityContainer(rarity: r, width: 12, height: 12, shape: BoxShape.circle),
                  const SizedBox(width: 8),
                  RarityText(AppColors.getRarityLabel(r), rarity: r),
                  const Spacer(),
                  Text("${percentage.toStringAsFixed(3)}%", style: const TextStyle(color: Colors.white70))
                ]
              );
            }
          )
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))]
      )
    ).then((_) => _handleUserInteraction());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              // --- ORIGINAL BANNER UI ---
              SizedBox(
                height: 260, 
                child: bannersLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : banners.isEmpty 
                    ? const Center(child: Text("No Banners")) 
                    : Column(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                key: ValueKey(banners.length), 
                                controller: _bannerController, 
                                itemCount: banners.length * 10000, 
                                onPageChanged: (i) => setState(() => _currentRealIndex = i % banners.length), 
                                itemBuilder: (ctx, i) {
                                  final index = i % banners.length;
                                  final b = banners[index];
                                  final active = index == _currentRealIndex;
                                  final currDetails = _getCurrencyDetails(b);
                                  final int baseCost = currDetails['cost'];

                                  return AnimatedScale(
                                    scale: active ? 1.0 : 0.9, 
                                    duration: const Duration(milliseconds: 200), 
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.symmetric(horizontal: 4), 
                                          decoration: BoxDecoration(
                                            gradient: active
                                              ? LinearGradient(
                                                colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight
                                              )
                                              : const LinearGradient(
                                                colors: [AppColors.card, AppColors.bg],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight
                                              ),
                                            borderRadius: BorderRadius.circular(16), 
                                            border: Border.all(color: active ? AppColors.accent : Colors.white10)
                                          ), 
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center, 
                                            children: [
                                              Text(b['name'] ?? "Unknown", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.grey)),
                                              const SizedBox(height: 8),
                                              Text(
                                                b['end'] != null ? "Ends: ${b['end']}" : "No Time Limit", 
                                                style: TextStyle(fontSize: 12, color: b['end'] != null ? Colors.redAccent : Colors.greenAccent)
                                              ),
                                              const SizedBox(height: 24),
                                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.white, 
                                                      foregroundColor: AppColors.accent,
                                                      minimumSize: const Size(100, 45), 
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                                    ), 
                                                    onPressed: _activePullCount != null ? null : () => _pull(1), 
                                                    child: _activePullCount == 1 
                                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                                                      : Row(children: [const Text("x1 "), Icon(currDetails['icon'], size: 16, color: currDetails['color']), const SizedBox(width: 4), Text("$baseCost", style: const TextStyle(fontWeight: FontWeight.bold))])
                                                  ),
                                                  const SizedBox(width: 16),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.accent, 
                                                      foregroundColor: Colors.white,
                                                      minimumSize: const Size(100, 45), 
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                                    ), 
                                                    onPressed: _activePullCount != null ? null : () => _pull(10), 
                                                    child: _activePullCount == 10
                                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                      : Row(children: [const Text("x10 "), Icon(currDetails['icon'], size: 16, color: currDetails['color']), const SizedBox(width: 4), Text("${baseCost * 10}", style: const TextStyle(fontWeight: FontWeight.bold))])
                                                  )
                                                ])
                                            ]
                                          )
                                        ),
                                        Positioned(
                                          top: 12, right: 16,
                                          child: InkWell(
                                            onTap: () => _showRateInfo(b['rate'] ?? {}),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                                              child: const Icon(Icons.question_mark, size: 16, color: Colors.white70)
                                            )
                                          )
                                        )
                                      ]
                                    )
                                  );
                                }
                              ),
                              if (banners.length > 1) ...[
                                Positioned(left: 0, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white24), onPressed: () => _scrollBanner(-1))),
                                Positioned(right: 0, child: IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white24), onPressed: () => _scrollBanner(1)))
                              ]
                            ]
                          )
                        ),
                        if (banners.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(banners.length, (index) {
                                return Container(
                                  width: 8, height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _currentRealIndex == index ? AppColors.accent : Colors.white24)
                                );
                              }
                            )
                          )
                        )
                      ]
                    )
              ),

              // --- RESULTS SECTION (Responsive) ---
              if (pullResults.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth;
                    
                    // Breakpoint Logic:
                    // > 600px: 10 items
                    // 400px - 600px: 5 items
                    // < 400px: 2 items
                    int cols;
                    if (w >= 600) {
                      cols = 10;
                    } else if (w >= 400) {
                      cols = 5;
                    } else {
                      cols = 2;
                    }

                    // Calculate precise width to fill row
                    final double itemWidth = (w / cols).floorToDouble(); 
                    final double itemHeight = itemWidth / 0.7; // Maintain aspect ratio

                    return Container(
                      width: w,
                      alignment: Alignment.center,
                      child: Wrap(
                        alignment: WrapAlignment.center, 
                        spacing: 0,
                        runSpacing: 8,
                        children: pullResults.map((hero) {
                          return SizedBox(
                            width: itemWidth,
                            height: itemHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0), 
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 130, // Native HeroCard width
                                  height: 185, 
                                  child: HeroCard(
                                    data: hero,
                                    onRename: _renameHero,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),

              // --- STORE SECTION (Responsive Scale) ---
              _buildStoreSection(),
              const SizedBox(height: 40),
            ]
          )
        ),

        // --- ANIMATION OVERLAY ---
        if (_currentOverlayHero != null) 
          Positioned.fill(
            child: GestureDetector(
              onTap: _showNextOverlay,
              child: Container(
                color: Colors.black.withOpacity(0.9),
                alignment: Alignment.center,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RarityText(
                        AppColors.getRarityLabel(_currentOverlayHero!['rarity']), 
                        rarity: _currentOverlayHero!['rarity'],
                        fontSize: 28,
                      ),
                      const SizedBox(height: 30),
                      
                      RarityContainer(
                        rarity: _currentOverlayHero!['rarity'],
                        width: 206, 
                        height: 291,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: HeroCard(data: _currentOverlayHero!, onRename: (a,b){})
                        ), 
                      ),
                      
                      const SizedBox(height: 20),
                      const Text("Tap to Continue", style: TextStyle(color: Colors.white54))
                    ]
                  )
                )
              )
            )
          )
      ]
    );
  }

  Widget _buildStoreSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        final double w = constraints.maxWidth;
        if (w >= 1000) {
          crossAxisCount = 8;
        } else if (w >= 500) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 2;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _storeItems.length,
              itemBuilder: (ctx, i) {
                final item = _storeItems[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.gem, color: item['color'], size: 36),
                      const SizedBox(height: 8),
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("${item['gems']} Gems", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                        child: Text(item['price'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                      )
                    ],
                  ),
                );
              }
            ),
          ],
        );
      }
    );
  }
}