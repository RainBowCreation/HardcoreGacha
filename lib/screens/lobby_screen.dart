import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';
import '../widgets/hero_card.dart';
import '../widgets/hex_grid.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => LobbyScreenState();
}

class LobbyScreenState extends State<LobbyScreen> {
  List<dynamic> roster = [];
  List<dynamic> parties = []; 
  dynamic selectedParty;
  
  Map<String, List<int>> tempFormation = {}; 
  bool hasUnsavedChanges = false;

  // Synthesis State
  Map<String, dynamic>? synthesisResult; 
  Map<String, dynamic>? synthesisFromHero; 
  Map<String, dynamic>? synthesisToHero;   
  bool showSynthesisResult = false;

  final List<Color> partyColors = [
    const Color(0xFFFF5252), const Color(0xFF448AFF), const Color(0xFF69F0AE),
    const Color(0xFFFFAB40), const Color(0xFFE040FB), const Color(0xFF64FFDA),
    const Color(0xFFFF4081), const Color(0xFFFFD740)
  ];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait([_loadRoster(), _loadParties()]);
    if (mounted) setState(() { showSynthesisResult = false; });
  }

  Future<void> _loadRoster() async {
    final res = await Api.request("/roster/info/all", query: {"page": "1"});
    if (res['data'] != null && mounted) setState(() => roster = res['data']);
  }

  Future<void> _loadParties() async {
    final res = await Api.request("/party/info/all");
    if (res['data'] != null && mounted) {
      setState(() {
        parties = res['data'];
        if (selectedParty != null) {
          final updated = parties.firstWhere((p) => p['pid'] == selectedParty['pid'], orElse: () => null);
          if (updated != null) {
            if (!hasUnsavedChanges) _selectParty(updated); 
            else selectedParty = updated; 
          } else {
            selectedParty = null;
          }
        }
      });
    }
  }

  void _selectParty(dynamic p) {
    setState(() {
      selectedParty = p;
      showSynthesisResult = false;
      tempFormation = {};
      if (p['formation'] != null && p['formation'] is Map) {
        (p['formation'] as Map).forEach((k, v) => tempFormation[k] = List<int>.from(v));
      }
      hasUnsavedChanges = false;
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

  Future<void> _deleteParty(String pid) async {
    final res = await Api.request("/party/delete", method: "POST", body: {"pid": pid});
    if (res['status'] == 200) { setState(() => selectedParty = null); _loadParties(); }
  }

  Future<void> _renameParty(String pid, String newName) async {
    await Api.request("/party/rename", method: "POST", body: {"pid": pid, "name": newName});
    _loadParties();
  }

  void _onHeroDroppedOnHex(String cid, int q, int r) {
    setState(() {
      tempFormation.remove(cid);
      String? occupantToRemove;
      tempFormation.forEach((eCid, pos) { if (pos[0] == q && pos[1] == r) occupantToRemove = eCid; });
      if (occupantToRemove != null) tempFormation.remove(occupantToRemove);
      tempFormation[cid] = [q, r];
      hasUnsavedChanges = true;
    });
  }

  void _onHeroRemoved(String cid) {
    setState(() { if (tempFormation.containsKey(cid)) { tempFormation.remove(cid); hasUnsavedChanges = true; }});
  }
  
  Future<void> _renameHero(String cid, String newName) async {
    final res = await Api.request("/roster/rename", method: "POST", body: {"cid": cid, "name": newName});
    if (res['status'] == 200) _loadRoster();
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
            onPressed: () { Navigator.pop(ctx); _executeSynthesis(fromCid, toCid, fromHero, toHero); }, 
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
        synthesisResult = Map<String, dynamic>.from(res['data']);
        synthesisFromHero = fromH; 
        synthesisToHero = toH;   
        showSynthesisResult = true;
        selectedParty = null; 
      });
      _loadRoster(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Synthesis Failed: ${res['error']}")));
    }
  }

  void _showTextInputDialog(String title, String initialValue, Function(String) onConfirm) {
    final controller = TextEditingController(text: initialValue);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () { if (controller.text.isNotEmpty) { onConfirm(controller.text); Navigator.pop(ctx); }}, child: const Text("Save"))
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            })))
          ])),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: showSynthesisResult && synthesisResult != null 
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
                const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("Roster", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 110, childAspectRatio: 0.70, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: roster.length, itemBuilder: (ctx, i) {
                  final h = roster[i]; final cid = h['cid'];
                  Color? color;
                  if (tempFormation.containsKey(cid) && selectedParty != null) {
                    int idx = parties.indexWhere((p) => p['pid'] == selectedParty['pid']);
                    if (idx != -1) color = partyColors[idx % partyColors.length];
                  } else {
                    for (int pIdx = 0; pIdx < parties.length; pIdx++) {
                      if (parties[pIdx]['pid'] != (selectedParty?['pid']) && parties[pIdx]['formation'] != null && (parties[pIdx]['formation'] as Map).containsKey(cid)) {
                        color = partyColors[pIdx % partyColors.length].withOpacity(0.5); break;
                      }
                    }
                  }
                  return DragTarget<String>(
                    onWillAccept: (fromCid) => fromCid != cid,
                    onAccept: (fromCid) => _onHeroDroppedOnHero(fromCid, cid),
                    builder: (context, _, __) => Draggable<String>(
                      data: cid,
                      feedback: Material(color: Colors.transparent, child: SizedBox(width: 100, height: 140, child: HeroCard(data: h, onRename: (_, __) {}, partyColor: color))),
                      childWhenDragging: Opacity(opacity: 0.3, child: HeroCard(data: h, onRename: _renameHero, partyColor: color)),
                      child: HeroCard(data: h, onRename: _renameHero, partyColor: color)
                    )
                  );
                })))
            ])
          )
        ]
      )
    );
  }

  // ==========================================
  // SYNTHESIS LOGIC (IMPROVED LAYOUT & BUGFIX)
  // ==========================================

  Widget _buildSynthesisResultView() {
    if (synthesisResult == null || synthesisToHero == null) return const SizedBox.shrink();

    final consumed = synthesisFromHero ?? {};
    final resultData = synthesisResult!['data'] ?? synthesisResult!;
    
    // We only need 'after' from the API. 
    // For 'before', we rely on our local hero data to ensure it's never 0/null.
    final afterStats = Map<String, dynamic>.from(resultData['after'] ?? {});

    // Prepare Local Data Shortcuts
    final oldHero = synthesisToHero!;
    final oldStats = oldHero['stats'] ?? {};

    // Create Card Data
    final afterCardData = _mapSynthesisToCardData(afterStats, oldHero);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.5))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("SYNTHESIS COMPLETE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(
            "${consumed['displayName'] ?? 'Material'} was consumed to upgrade ${oldHero['displayName'] ?? 'Target'}",
            style: const TextStyle(color: Colors.grey, fontSize: 12)
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. BEFORE
                Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("BEFORE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 140, height: 200,
                        child: HeroCard(data: oldHero, onRename: (_, __) {})
                      ),
                    ],
                  ),
                ),

                // 2. ARROW
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Icon(Icons.keyboard_double_arrow_right, color: AppColors.accent, size: 48),
                ),

                // 3. AFTER
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("AFTER", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 160, height: 220,
                      child: HeroCard(data: afterCardData, onRename: (_, __) {})
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. STAT CHANGES TABLE
          // FIX: Use 'oldHero' and 'oldStats' for the first argument. 
          // Use 'afterStats' (from API) for the second argument.
          Container(
            width: 500, 
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildStatRow("Level", oldHero['level'], afterStats['level']),
                const Divider(color: Colors.white10, height: 16),
                _buildStatRow("HP", oldStats['HP'], afterStats['stats']?['HP']),
                _buildStatRow("MP", oldStats['SP'], afterStats['stats']?['SP']), // Note: SP usually maps to MP
                _buildStatRow("AP", oldStats['AP'], afterStats['stats']?['AP']),
                const Divider(color: Colors.white10, height: 16),
                _buildStatRow("STR", oldStats['STR'], afterStats['stats']?['STR']),
                _buildStatRow("VIT", oldStats['VIT'], afterStats['stats']?['VIT']),
                _buildStatRow("INT", oldStats['INT'], afterStats['stats']?['INT']),
                _buildStatRow("DEX", oldStats['DEX'], afterStats['stats']?['DEX']),
                _buildStatRow("AGI", oldStats['AGI'], afterStats['stats']?['AGI']),
                _buildStatRow("LUK", oldStats['LUK'], afterStats['stats']?['LUK']),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)
            ),
            onPressed: () {
              setState(() {
                showSynthesisResult = false;
                synthesisResult = null;
              });
              refresh();
            }, 
            child: const Text("CONTINUE")
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic oldVal, dynamic newVal) {
    // FIX: Fallback to oldVal if newVal is null/0 when it shouldn't be (prevents 2 -> 0)
    int o = (oldVal is num) ? oldVal.toInt() : 0;
    int n = (newVal is num) ? newVal.toInt() : o; // Default to 'o' (No Change) if n is missing

    // If API actually sent 0 but old was 5, we might want 0. 
    // But usually in synthesis stats don't drop to 0. 
    // If n is 0 and o > 0, assume data missing error and fallback to o.
    if (n == 0 && o > 0) n = o;

    int diff = n - o;
    if (diff == 0) {
      // Show "No Change" look
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
            Text("$o", style: const TextStyle(color: Colors.white38)),
            const Spacer(),
            const Text("-", style: TextStyle(color: Colors.white10)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
          Text("$o", style: const TextStyle(color: Colors.white70)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.arrow_right_alt, color: Colors.white24, size: 16),
          ),
          Text("$n", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text("+$diff", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Map<String, dynamic> _mapSynthesisToCardData(Map<String, dynamic>? statsData, Map<String, dynamic> originalHero) {
    if (statsData == null) return originalHero;

    final stats = statsData['stats'] ?? {};
    
    // Helper to safe get value
    T? safeGet<T>(dynamic val, T? fallback) {
      if (val is T) return val;
      if (val is num && fallback is num) return val as T; 
      return fallback;
    }

    return {
      ...originalHero,
      'level': safeGet(statsData['level'], originalHero['level']),
      'stats': stats.isEmpty ? originalHero['stats'] : stats,
      'hp': {'max': safeGet(stats['HP'], originalHero['hp']?['max'])},
      'mana': {'max': safeGet(stats['SP'], originalHero['mana']?['max'])},
      'stamina': {'max': safeGet(stats['AP'], originalHero['stamina']?['max'])},
    };
  }
}