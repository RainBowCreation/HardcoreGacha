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

  // RAW COLORS ONLY (No MaterialAccentColor)
  final List<Color> partyColors = [
    const Color(0xFFFF5252), // Red
    const Color(0xFF448AFF), // Blue
    const Color(0xFF69F0AE), // Green
    const Color(0xFFFFAB40), // Orange
    const Color(0xFFE040FB), // Purple
    const Color(0xFF64FFDA), // Teal
    const Color(0xFFFF4081), // Pink
    const Color(0xFFFFD740), // Amber
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
      if (mounted) setState(() { isServerOnline = isOnline; onlinePlayers = players; });
    } catch (e) {
      if (mounted) setState(() => isServerOnline = false);
    }
  }

  Future<void> _loadBanners() async {
    setState(() => bannersLoading = true);
    final res = await Api.request("/gacha/banners");
    if (mounted) setState(() { bannersLoading = false; if (res['data'] != null) banners = res['data']; });
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
        }
      });
    }
  }

  void _selectParty(dynamic p) {
    setState(() {
      selectedParty = p;
      tempFormation = {};
      if (p['formation'] != null && p['formation'] is Map) {
        (p['formation'] as Map).forEach((k, v) {
          tempFormation[k] = List<int>.from(v);
        });
      }
      hasUnsavedChanges = false;
    });
  }

  void _onHeroDroppedOnHex(String cid, int q, int r) {
    setState(() {
      tempFormation.remove(cid);
      String? occupantToRemove;
      tempFormation.forEach((existingCid, pos) {
        if (pos[0] == q && pos[1] == r) occupantToRemove = existingCid;
      });
      if (occupantToRemove != null) tempFormation.remove(occupantToRemove);
      tempFormation[cid] = [q, r];
      hasUnsavedChanges = true;
    });
  }

  void _onHeroRemoved(String cid) {
    setState(() {
      if (tempFormation.containsKey(cid)) {
        tempFormation.remove(cid);
        hasUnsavedChanges = true;
      }
    });
  }

  Future<void> _saveFormation() async {
    if (selectedParty == null) return;
    final body = { "pid": selectedParty['pid'], "formation": tempFormation };
    final res = await Api.request("/party/setup", method: "POST", body: body);
    if (res['status'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formation Saved!")));
      setState(() => hasUnsavedChanges = false);
      _loadParties(); 
    } else {
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

  Future<void> _pull(int count) async {
    if (banners.isEmpty) return;
    final bannerId = banners[_currentBannerIndex]['id'];
    final res = await Api.request("/gacha/pull", method: "POST", body: {"bannerId": bannerId, "count": count});
    if (res['data'] != null && res['data']['result'] != null) {
      setState(() { pullResults = res['data']['result']; _loadRoster(); });
    }
  }

  Future<void> _renameHero(String cid, String newName) async {
    final res = await Api.request("/roster/rename", method: "POST", body: {"cid": cid, "name": newName});
    if (res['status'] == 200) {
      _loadRoster();
      setState(() { pullResults = pullResults.map((h) => h['cid'] == cid ? {...h, 'displayName': newName} : h).toList(); });
    }
  }

  void _showTextInputDialog(String title, String initialValue, Function(String) onConfirm) {
    final controller = TextEditingController(text: initialValue);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () { if (controller.text.isNotEmpty) { onConfirm(controller.text); Navigator.pop(ctx); } }, child: const Text("Save"))
      ],
    ));
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
            ]),
          ),
          IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.red), onPressed: widget.onLogout),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _viewIndex,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        onTap: (i) { 
          setState(() => _viewIndex = i); 
          // If switching to Party Tab (index 1), load everything
          if (i == 1) {
            _loadRoster(); 
            _loadParties(); 
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "GACHA"),
          BottomNavigationBarItem(icon: Icon(Icons.hexagon), label: "PARTY"),
        ],
      ),
      body: IndexedStack(
        index: _viewIndex,
        children: [
          // GACHA VIEW
          SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 16),
              SizedBox(height: 240, child: bannersLoading ? const Center(child: CircularProgressIndicator()) : banners.isEmpty ? const Center(child: Text("No Banners")) : PageView.builder(controller: _bannerController, itemCount: banners.length, onPageChanged: (i) => setState(()=>_currentBannerIndex=i), itemBuilder: (ctx, i) {
                final b = banners[i]; final active = i==_currentBannerIndex;
                return AnimatedScale(scale: active?1.0:0.9, duration: const Duration(milliseconds: 200), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(gradient: active?const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]):const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF020617)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: active?AppColors.accent:Colors.white10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(b['name'], style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: active?Colors.white:Colors.grey)),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.accent), onPressed: ()=>_pull(1), child: const Text("SINGLE")),
                    const SizedBox(width: 16),
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white), onPressed: ()=>_pull(10), child: const Text("MULTI (x10)"))
                  ])
                ])));
              })),
              Padding(padding: const EdgeInsets.all(16), child: HeroGrid(heroes: pullResults, onRename: _renameHero))
            ]),
          ),
          
          // PARTY VIEW (Replaces previous Roster tab position)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANEL: PARTY LIST
                Expanded(flex: 1, child: Column(children: [
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.add, size: 16), label: const Text("NEW PARTY"), onPressed: ()=>_showTextInputDialog("Name", "", (v)=>_createParty(v)))),
                  const SizedBox(height: 8),
                  Expanded(child: Card(child: ListView.builder(itemCount: parties.length, itemBuilder: (ctx, i) {
                    final p = parties[i]; final c = partyColors[i%partyColors.length];
                    return ListTile(leading: CircleAvatar(radius: 6, backgroundColor: c), title: Text(p['partyName']??p['pid'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: (selectedParty!=null&&selectedParty['pid']==p['pid'])?Colors.white:Colors.grey)), selected: (selectedParty!=null&&selectedParty['pid']==p['pid']), selectedTileColor: AppColors.accent.withOpacity(0.1), onTap: ()=>_selectParty(p));
                  })))
                ])),
                const SizedBox(width: 16),
                
                // RIGHT PANEL: HEX GRID & MINI ROSTER
                Expanded(flex: 3, child: Column(children: [
                  Container(height: 340, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: selectedParty==null?const Center(child: Text("Select Party")):Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(onTap: ()=>_showTextInputDialog("Rename", selectedParty['partyName']??"", (v)=>_renameParty(selectedParty['pid'], v)), child: Text(selectedParty['partyName']??"Unknown", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8), const Icon(Icons.edit, size: 14, color: Colors.grey)
                    ]),
                    if(hasUnsavedChanges) Padding(padding: const EdgeInsets.only(top: 8), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact), icon: const Icon(Icons.check, size: 14), label: const Text("SAVE CHANGES"), onPressed: _saveFormation)),
                    const SizedBox(height: 12),
                    Expanded(child: HexFormationView(formation: tempFormation, roster: roster, onHeroDrop: _onHeroDroppedOnHex, onHeroRemove: _onHeroRemoved))
                  ])),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("AVAILABLE HEROES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))),
                  Expanded(child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 110, childAspectRatio: 0.70, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: roster.length, itemBuilder: (ctx, i) {
                    final h = roster[i]; final cid = h['cid'];
                    
                    // Highlight Logic with Raw Colors
                    bool inCurrent = tempFormation.containsKey(cid);
                    Color? color;
                    if(inCurrent && selectedParty!=null) {
                      int idx = parties.indexWhere((p) => p['pid'] == selectedParty['pid']);
                      if(idx != -1) color = partyColors[idx % partyColors.length];
                    } else {
                      for (int pIdx = 0; pIdx < parties.length; pIdx++) {
                        final p = parties[pIdx];
                        if (p['pid'] != (selectedParty?['pid']) && p['formation'] != null && (p['formation'] as Map).containsKey(cid)) {
                          color = partyColors[pIdx % partyColors.length].withOpacity(0.5);
                          break;
                        }
                      }
                    }

                    // Fallback to avoid null color errors if no party assigned
                    // if (color == null) {
                    //   color = AppColors.getRarityColor(1);
                    // }

                    return Draggable<String>(
                      data: cid,
                      feedback: Material(color: Colors.transparent, child: SizedBox(width: 100, height: 140, child: HeroCard(data: h, onRename: (_,__) {}, partyColor: color))),
                      childWhenDragging: Opacity(opacity: 0.3, child: HeroCard(data: h, onRename: _renameHero, partyColor: color)),
                      child: HeroCard(data: h, onRename: _renameHero, partyColor: color),
                    );
                  })))
                ]))
              ],
            ),
          )
        ],
      ),
    );
  }
}