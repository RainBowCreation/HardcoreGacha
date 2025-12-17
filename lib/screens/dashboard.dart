import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';
import '../widgets/hero_card.dart';
import '../widgets/hex_grid.dart';

class MainDashboard extends StatefulWidget {
  final VoidCallback onLogout;
  const MainDashboard({super.key, required this.onLogout});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _viewIndex = 0;
  List<dynamic> roster = [];
  List<dynamic> pullResults = [];
  List<dynamic> parties = []; 
  dynamic selectedParty;

  Map<String, List<int>> tempFormation = {}; 
  bool hasUnsavedChanges = false;

  List<dynamic> banners = [];
  bool bannersLoading = false;
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController(viewportFraction: 0.9);

  bool isServerOnline = false;
  int onlinePlayers = 0;
  Timer? _statusTimer;

  // --- SYNTHESIS STATE ---
  Map<String, dynamic>? synthesisResult; 
  Map<String, dynamic>? synthesisFromHero; // Store original hero data
  Map<String, dynamic>? synthesisToHero;   // Store target hero data
  bool showSynthesisResult = false;

  final List<Color> partyColors = [
    const Color(0xFFFF5252), const Color(0xFF448AFF), const Color(0xFF69F0AE),
    const Color(0xFFFFAB40), const Color(0xFFE040FB), const Color(0xFF64FFDA),
    const Color(0xFFFF4081), const Color(0xFFFFD740)
  ];

  @override
  void initState() {
    super.initState();
    _loadBanners();
    _loadRoster();
    _loadParties(); 
    _checkServerStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _checkServerStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    try {
      final healthRes = await Api.request("/health", isV1: false);
      final isOnline = healthRes['message'] == "ok";
      int players = onlinePlayers;
      if (isOnline) {
        final infoRes = await Api.request("/serverinfo", isV1: false);
        if (infoRes['data'] != null) players = infoRes['data']['online_players'] ?? 0;
      }
      if (mounted) setState(() {
            isServerOnline = isOnline; onlinePlayers = players; }
        );
    }
    catch (e) {
      if (mounted) setState(() => isServerOnline = false);
    }
  }

  Future<void> _loadBanners() async {
    setState(() => bannersLoading = true);
    final res = await Api.request("/gacha/banners");
    if (mounted) setState(() {
          bannersLoading = false;if (res['data'] != null) banners = res['data']; }
      );
  }

  Future<void> _loadRoster() async {
    final res = await Api.request("/roster/info/all", query: {"page": "1"});
    if (res['data'] != null) setState(() => roster = res['data']);
  }

  Future<void> _loadParties() async {
    final res = await Api.request("/party/info/all");
    if (res['data'] != null) {
      setState(() {
          parties = res['data'];
          if (selectedParty != null) {
            final updated = parties.firstWhere((p) => p['pid'] == selectedParty['pid'], orElse: () => null);
            if (updated != null) {
              if (!hasUnsavedChanges) _selectParty(updated); 
              else selectedParty = updated; 
            }
            else {
              selectedParty = null;
            }
          }
        }
      );
    }
  }

  void _selectParty(dynamic p) {
    setState(() {
        selectedParty = p;
        showSynthesisResult = false;
        tempFormation = {};
        if (p['formation'] != null && p['formation'] is Map) {
          (p['formation'] as Map).forEach((k, v) {
              tempFormation[k] = List<int>.from(v);
            }
          );
        }
        hasUnsavedChanges = false;
      }
    );
  }

  void _onHeroDroppedOnHex(String cid, int q, int r) {
    setState(() {
        tempFormation.remove(cid);
        String? occupantToRemove;
        tempFormation.forEach((existingCid, pos) {
            if (pos[0] == q && pos[1] == r) occupantToRemove = existingCid;
          }
        );
        if (occupantToRemove != null) tempFormation.remove(occupantToRemove);
        tempFormation[cid] = [q, r];
        hasUnsavedChanges = true;
      }
    );
  }

  void _onHeroRemoved(String cid) {
    setState(() {
        if (tempFormation.containsKey(cid)) {
          tempFormation.remove(cid);
          hasUnsavedChanges = true;
        }
      }
    );
  }

  Future<void> _saveFormation() async {
    if (selectedParty == null) return;
    final body = { "pid": selectedParty['pid'], "formation": tempFormation };
    final res = await Api.request("/party/setup", method: "POST", body: body);
    if (res['status'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formation Saved!")));
      setState(() => hasUnsavedChanges = false);
      _loadParties(); 
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['error']}")));
    }
  }

  Future<void> _createParty(String name) async {
    final res = await Api.request("/party/create", method: "POST", body: {"name": name});
    if (res['status'] == 200 || res['status'] == 201) _loadParties();
  }

  Future<void> _renameParty(String pid, String newName) async {
    await Api.request("/party/rename", method: "POST", body: {"pid": pid, "name": newName});
    _loadParties();
  }

  Future<void> _deleteParty(String pid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Party"),
        content: const Text("Are you sure you want to delete this party?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete"))
        ]
      )
    );

    if (confirm == true) {
      final res = await Api.request("/party/delete", method: "POST", body: {"pid": pid});
      if (res['status'] == 200) {
        setState(() => selectedParty = null);
        _loadParties();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Party Deleted")));
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['error']}")));
      }
    }
  }

  void _onHeroDroppedOnHero(String fromCid, String toCid) {
    if (fromCid == toCid) return;
    final fromHero = roster.firstWhere((h) => h['cid'] == fromCid, orElse: () => null);
    final toHero = roster.firstWhere((h) => h['cid'] == toCid, orElse: () => null);
    if (fromHero == null || toHero == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Synthesis", style: TextStyle(color: Colors.redAccent)),
        content: Text("WARNING: '${fromHero['displayName']}' will be consumed to upgrade '${toHero['displayName']}'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSynthesis(fromCid, toCid, fromHero, toHero);
            }, 
            child: const Text("CONFIRM")
          )
        ]
      )
    );
  }

  Future<void> _executeSynthesis(String fromCid, String toCid, Map<String, dynamic> fromH, Map<String, dynamic> toH) async {
    final res = await Api.request("/roster/synthesis", method: "POST", body: {"from": fromCid, "to": toCid});
    if (res['status'] == 200 && res['data'] != null) {
      setState(() {
          synthesisResult = res['data'];
          synthesisFromHero = fromH; // Save original data to display later
          synthesisToHero = toH;     // Save original data to display later
          showSynthesisResult = true;
          selectedParty = null; 
        }
      );
      _loadRoster(); 
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Synthesis Failed: ${res['error']}")));
    }
  }

  Future<void> _pull(int count) async {
    if (banners.isEmpty) return;
    final bannerId = banners[_currentBannerIndex]['id'];
    final res = await Api.request("/gacha/pull", method: "POST", body: {"bannerId": bannerId, "count": count});
    if (res['data'] != null && res['data']['result'] != null) {
      setState(() {
          pullResults = res['data']['result']; _loadRoster(); }
      );
    }
  }

  Future<void> _renameHero(String cid, String newName) async {
    final res = await Api.request("/roster/rename", method: "POST", body: {"cid": cid, "name": newName});
    if (res['status'] == 200) {
      _loadRoster();
      setState(() {
          pullResults = pullResults.map((h) => h['cid'] == cid ? {...h, 'displayName': newName} : h).toList(); }
      );
    }
  }

  void _showTextInputDialog(String title, String initialValue, Function(String) onConfirm) {
    final controller = TextEditingController(text: initialValue);
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(title), content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () {
              if (controller.text.isNotEmpty) {
                onConfirm(controller.text); Navigator.pop(ctx); }
            }, child: const Text("Save"))
        ]
      ));
  }

  // --- MAPPER: Merges Original Hero Data with New Synthesis Stats ---
  Map<String, dynamic> _mapSynthesisToCardData(Map<String, dynamic>? synthData, Map<String, dynamic>? originalHero, String labelPrefix) {
    if (synthData == null) return {};
    if (originalHero == null) return {}; // Should not happen

    // 1. Get stats from synthesis result
    final stats = synthData['stats'] ?? {}; 
    final level = synthData['level'] ?? 1;

    // 2. Create a new map based on the ORIGINAL hero (so we keep race, class, display name, rarity)
    final merged = Map<String, dynamic>.from(originalHero);

    // 3. Override with new values
    merged['displayName'] = "$labelPrefix: ${originalHero['displayName'] ?? originalHero['class']}";
    merged['level'] = level;
    merged['stats'] = stats;

    // 4. Map top-level HP/MP/AP for the StatBox widget
    //    Note: The Synthesis API uses "HP", "SP", "AP". The HeroCard expects lowercase keys with "max".
    merged['hp'] = {"max": stats['HP'] ?? 0};
    merged['mana'] = {"max": stats['SP'] ?? 0};
    merged['stamina'] = {"max": stats['AP'] ?? 0};

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(text: const TextSpan(text: "HG ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20), children: [TextSpan(text: "CLIENT", style: TextStyle(color: AppColors.accent))])),
        backgroundColor: Colors.black54,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: isServerOnline ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (isServerOnline ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)])),
                const SizedBox(width: 8),
                Text(isServerOnline ? "$onlinePlayers Online" : "Offline", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70))
              ])
          ),
          IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.red), onPressed: widget.onLogout)
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _viewIndex,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        onTap: (i) { 
          setState(() {
              _viewIndex = i;
              if (i == 1) { 
                _loadRoster(); 
                _loadParties(); 
                showSynthesisResult = false; 
              }
            }
          );
        },
        items: const[
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "GACHA"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "LOBBY")
        ]
      ),
      body: IndexedStack(
        index: _viewIndex,
        children: [
          // GACHA
          SingleChildScrollView(
            child: Column(children: [
                const SizedBox(height: 16),
                SizedBox(height: 240, child: bannersLoading ? const Center(child: CircularProgressIndicator()) : banners.isEmpty ? const Center(child: Text("No Banners")) : PageView.builder(controller: _bannerController, itemCount: banners.length, onPageChanged: (i) => setState(() => _currentBannerIndex = i), itemBuilder: (ctx, i) {
                          final b = banners[i]; final active = i == _currentBannerIndex;
                          return AnimatedScale(scale: active ? 1.0 : 0.9, duration: const Duration(milliseconds: 200), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(gradient: active ? const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]) : const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF020617)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? AppColors.accent : Colors.white10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(b['name'], style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.grey)),
                                  const SizedBox(height: 24),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.accent), onPressed: () => _pull(1), child: const Text("SINGLE")),
                                      const SizedBox(width: 16),
                                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white), onPressed: () => _pull(10), child: const Text("MULTI (x10)"))
                                    ])
                                ])));
                        }
                      )),
                Padding(padding: const EdgeInsets.all(16), child: HeroGrid(heroes: pullResults, onRename: _renameHero))
              ])
          ),

          // LOBBY
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: Column(children: [
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.add, size: 16), label: const Text("NEW PARTY"), onPressed: () => _showTextInputDialog("Name", "", (v) => _createParty(v)))),
                      const SizedBox(height: 8),
                      Expanded(child: Card(child: ListView.builder(itemCount: parties.length, itemBuilder: (ctx, i) {
                              final p = parties[i]; final c = partyColors[i % partyColors.length];
                              return ListTile(
                                leading: CircleAvatar(radius: 6, backgroundColor: c), 
                                title: Text(p['partyName'] ?? p['pid'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: (selectedParty != null && selectedParty['pid'] == p['pid']) ? Colors.white : Colors.grey)), 
                                selected: (selectedParty != null && selectedParty['pid'] == p['pid']), 
                                selectedTileColor: AppColors.accent.withOpacity(0.1), 
                                trailing: (selectedParty != null && selectedParty['pid'] == p['pid']) ? IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent), onPressed: () => _deleteParty(p['pid'])) : null,
                                onTap: () => _selectParty(p)
                              );
                            }
                          )))
                    ])),
                const SizedBox(width: 16),

                Expanded(flex: 3, child: 
                  showSynthesisResult && synthesisResult != null 
                    ? _buildSynthesisResultView()
                    : Column(children: [
                        Container(height: 340, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: selectedParty == null ? const Center(child: Text("")) : Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    GestureDetector(onTap: () => _showTextInputDialog("Rename", selectedParty['partyName'] ?? "", (v) => _renameParty(selectedParty['pid'], v)), child: Text(selectedParty['partyName'] ?? "Unknown", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 8), const Icon(Icons.edit, size: 14, color: Colors.grey)
                                  ]),
                                if(hasUnsavedChanges) Padding(padding: const EdgeInsets.only(top: 8), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact), icon: const Icon(Icons.check, size: 14), label: const Text("SAVE CHANGES"), onPressed: _saveFormation)),
                                const SizedBox(height: 12),
                                Expanded(child: HexFormationView(formation: tempFormation, roster: roster, onHeroDrop: _onHeroDroppedOnHex, onHeroRemove: _onHeroRemoved))
                              ])),
                        const SizedBox(height: 16),
                        const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("AVAILABLE HEROES (Drag to Party OR onto another Hero to Synthesize)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))),
                        Expanded(child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 110, childAspectRatio: 0.70, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: roster.length, itemBuilder: (ctx, i) {
                                final h = roster[i]; final cid = h['cid'];
                                bool inCurrent = tempFormation.containsKey(cid);
                                Color? color;
                                if (inCurrent && selectedParty != null) {
                                  int idx = parties.indexWhere((p) => p['pid'] == selectedParty['pid']);
                                  if (idx != -1) color = partyColors[idx % partyColors.length];
                                }
                                else {
                                  for (int pIdx = 0; pIdx < parties.length; pIdx++) {
                                    final p = parties[pIdx];
                                    if (p['pid'] != (selectedParty?['pid']) && p['formation'] != null && (p['formation'] as Map).containsKey(cid)) {
                                      color = partyColors[pIdx % partyColors.length].withOpacity(0.5);
                                      break;
                                    }
                                  }
                                }

                                return DragTarget<String>(
                                  onWillAccept: (fromCid) => fromCid != cid,
                                  onAccept: (fromCid) => _onHeroDroppedOnHero(fromCid, cid),
                                  builder: (context, _, __) => Draggable<String>(
                                    data: cid,
                                    feedback: Material(color: Colors.transparent, child: SizedBox(width: 100, height: 140, child: HeroCard(data: h, onRename: (_, __) {
                                          }, partyColor: color))),
                                    childWhenDragging: Opacity(opacity: 0.3, child: HeroCard(data: h, onRename: _renameHero, partyColor: color)),
                                    child: HeroCard(data: h, onRename: _renameHero, partyColor: color)
                                  )
                                );
                              }
                            )))
                      ]))
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildSynthesisResultView() {
    if (synthesisResult == null || synthesisFromHero == null || synthesisToHero == null) return const SizedBox();

    final beforeStats = synthesisResult!['before']['stats'] ?? {};
    final afterStats = synthesisResult!['after']['stats'] ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          const Text("SYNTHESIS COMPLETE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 140, height: 200, 
                child: HeroCard(
                  data: _mapSynthesisToCardData(synthesisResult!['before'], synthesisToHero, "Before"), 
                  onRename: (_, __) {
                  }
                )
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Icon(Icons.arrow_forward, size: 40, color: Colors.grey)),
              SizedBox(width: 140, height: 200, 
                child: HeroCard(
                  data: _mapSynthesisToCardData(synthesisResult!['after'], synthesisToHero, "After"), 
                  onRename: (_, __) {
                  }, 
                  partyColor: Colors.greenAccent
                )
              )
            ]),
          const SizedBox(height: 32),
          const Divider(color: Colors.white10),
          Expanded(child: ListView(children: [
                _buildStatChangeRow("Level", synthesisResult!['before']['level'] ?? 0, synthesisResult!['after']['level'] ?? 0),
                _buildStatChangeRow("HP", beforeStats['HP'] ?? 0, afterStats['HP'] ?? 0),
                _buildStatChangeRow("SP (MP)", beforeStats['SP'] ?? 0, afterStats['SP'] ?? 0),
                _buildStatChangeRow("AP", beforeStats['AP'] ?? 0, afterStats['AP'] ?? 0),
                const Divider(color: Colors.white10),
                _buildStatChangeRow("STR", beforeStats['STR'] ?? 0, afterStats['STR'] ?? 0),
                _buildStatChangeRow("VIT", beforeStats['VIT'] ?? 0, afterStats['VIT'] ?? 0),
                _buildStatChangeRow("INT", beforeStats['INT'] ?? 0, afterStats['INT'] ?? 0),
                _buildStatChangeRow("DEX", beforeStats['DEX'] ?? 0, afterStats['DEX'] ?? 0),
                _buildStatChangeRow("AGI", beforeStats['AGI'] ?? 0, afterStats['AGI'] ?? 0),
                _buildStatChangeRow("LUK", beforeStats['LUK'] ?? 0, afterStats['LUK'] ?? 0)
              ])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => setState(() => showSynthesisResult = false), child: const Text("CLOSE"))
        ]
      )
    );
  }

  Widget _buildStatChangeRow(String label, num oldVal, num newVal) {
    num diff = newVal - oldVal;

    if (diff == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
        child: Row(children: [
            SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            Text("$oldVal", style: const TextStyle(color: Colors.grey)),
            const Spacer(), const Icon(Icons.arrow_forward, size: 12, color: Colors.grey), const Spacer(),
            Text("$newVal", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
            const SizedBox(width: 8), const Icon(Icons.remove, size: 14, color: Colors.grey)
          ])
      );
    }

    bool isUp = diff > 0;
    Color c = isUp ? Colors.greenAccent : Colors.redAccent;
    IconData icon = isUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      child: Row(children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Text("$oldVal", style: const TextStyle(color: Colors.grey)),
          const Spacer(), const Icon(Icons.arrow_forward, size: 12, color: Colors.grey), const Spacer(),
          Text("$newVal", style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
          const SizedBox(width: 8), Icon(icon, size: 14, color: c),
          const SizedBox(width: 4), Text(isUp ? "+$diff" : "$diff", style: TextStyle(color: c, fontSize: 12))
        ])
    );
  }
}
