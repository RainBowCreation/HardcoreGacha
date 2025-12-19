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
  // Roster State
  List<dynamic> roster = [];
  int _currentPage = 1;
  int _totalHeroes = 0;
  bool _isLoadingRoster = false;
  final ScrollController _rosterScrollController = ScrollController();
  
  // Party State
  List<dynamic> parties = []; 
  dynamic selectedParty;

  // Formation State
  Map<String, List<int>> tempFormation = {}; 
  bool hasUnsavedChanges = false;

  // Synthesis State
  Map<String, dynamic>? synthesisResult; 
  Map<String, dynamic>? synthesisFromHero; 
  Map<String, dynamic>? synthesisToHero;   
  bool showSynthesisResult = false;
  
  // --- NEW SYNTHESIS MODE STATE ---
  bool _isSynthesisMode = false;
  Set<String> _synthesisMaterials = {};
  String? _synthesisTarget;
  // -------------------------------

  // UI State
  bool? _isSidebarCollapsed;
  bool _isNarrowSidebarOpen = false;

  final List<Color> partyColors = [
    const Color(0xFFFF5252), const Color(0xFF448AFF), const Color(0xFF69F0AE),
    const Color(0xFFFFAB40), const Color(0xFFE040FB), const Color(0xFF48C27F),
    const Color(0xFFFF4081), const Color(0xFFFFD740)
  ];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _rosterScrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadRosterCount();
    await Future.wait([_loadRoster(page: 1), _loadParties()]);
    if (mounted) setState(() => showSynthesisResult = false);
  }

  Future<void> _loadRosterCount() async {
    final res = await Api.request("/roster/count");
    if (res['count'] != null && mounted) {
      setState(() {
        _totalHeroes = int.tryParse(res['count'].toString()) ?? 0;
      });
    }
  }

  Future<void> _loadRoster({required int page}) async {
    setState(() {
      _isLoadingRoster = true;
      _currentPage = page;
    });

    final res = await Api.request("/roster/info/all", query: {"page": page.toString()});
    
    if (mounted) {
      setState(() {
        if (res['data'] != null) {
          roster = res['data'];
          if (_rosterScrollController.hasClients) {
            _rosterScrollController.jumpTo(0);
          }
        }
        _isLoadingRoster = false;
      });
    }
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
    if (selectedParty!=null) {
      if (selectedParty['pid'] == p['pid']) {
        setState(() { selectedParty = null; });
      }
    }
    else {
      setState(() {
          selectedParty = p;
          showSynthesisResult = false;
          tempFormation = {};
          if (p['formation'] != null && p['formation'] is Map) {
            (p['formation'] as Map).forEach((k, v) => tempFormation[k] = List<int>.from(v));
          }
          hasUnsavedChanges = false;
          
          // Ensure synthesis mode is off when selecting party to avoid confusion
          _isSynthesisMode = false;
          _synthesisMaterials.clear();
          _synthesisTarget = null;
        }
      );
    }
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

  Future<void> _deleteParty(String pid) async {
    final res = await Api.request("/party/delete", method: "POST", body: {"pid": pid});
    if (res['status'] == 200) {
      setState(() => selectedParty = null); _loadParties(); }
  }

  Future<void> _renameParty(String pid, String newName) async {
    await Api.request("/party/rename", method: "POST", body: {"pid": pid, "name": newName});
    _loadParties();
  }

  void _onHeroDroppedOnHex(String cid, int q, int r) {
    setState(() {
        tempFormation.remove(cid);
        String? occupantToRemove;
        tempFormation.forEach((eCid, pos) {
            if (pos[0] == q && pos[1] == r) occupantToRemove = eCid; }
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
          tempFormation.remove(cid); hasUnsavedChanges = true; }
      }
    );
  }

  Future<void> _renameHero(String cid, String newName) async {
    final res = await Api.request("/roster/rename", method: "POST", body: {"cid": cid, "name": newName});
    if (res['status'] == 200) _loadRoster(page: _currentPage);
  }

  // --- SYNTHESIS LOGIC START ---

  void _toggleSynthesisMode() {
    setState(() {
      _isSynthesisMode = !_isSynthesisMode;
      // Reset selections when toggling
      _synthesisMaterials.clear();
      _synthesisTarget = null;
    });
  }

  // Single Click in Synthesis Mode
  void _onSynthesisHeroTap(String cid) {
    if (_synthesisTarget == cid) {
      // If tapping the Target, trigger confirmation
      _confirmMultiSynthesis();
    } else {
      setState(() {
        // Toggle material selection
        if (_synthesisMaterials.contains(cid)) {
          _synthesisMaterials.remove(cid);
        } else {
          _synthesisMaterials.add(cid);
        }
      });
    }
  }

  // Double Click / Long Press in Synthesis Mode
  void _onSynthesisHeroSetTarget(String cid) {
    setState(() {
      if (_synthesisTarget == cid) {
        // Deselect if already target
        _synthesisTarget = null;
      } else {
        _synthesisTarget = cid;
        // Ensure target isn't in material list
        _synthesisMaterials.remove(cid);
      }
    });
  }

  void _confirmMultiSynthesis() {
    if (_synthesisTarget == null || _synthesisMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a target (Green) and at least one material (Red).")));
      return;
    }

    final toHero = roster.firstWhere((h) => h['cid'] == _synthesisTarget, orElse: () => null);
    if (toHero == null) return;
    
    // For display in dialog, just show first material name + count
    final firstMatCid = _synthesisMaterials.first;
    final firstMat = roster.firstWhere((h) => h['cid'] == firstMatCid, orElse: () => null);
    
    String matsText = "'${firstMat?['displayName']}'";
    if (_synthesisMaterials.length > 1) {
      matsText += " and ${_synthesisMaterials.length - 1} others";
    }

    // Dummy "fromHero" for the result view logic (visual only)
    Map<String, dynamic> dummyFromHero = firstMat != null ? Map.from(firstMat) : {};
    dummyFromHero['displayName'] = "Selected Materials";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Synthesis", style: TextStyle(color: Colors.redAccent)),
        content: Text("WARNING: $matsText will be consumed to upgrade '${toHero['displayName']}'.\n\nThis cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSynthesis(_synthesisMaterials.toList(), _synthesisTarget!, dummyFromHero, toHero); 
            }, 
            child: const Text("CONFIRM")
          )
        ]
      )
    );
  }

  // Legacy Drop Logic (1-on-1)
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
              _executeSynthesis([fromCid], toCid, fromHero, toHero); 
            }, 
            child: const Text("CONFIRM")
          )
        ]
      )
    );
  }
  // --- SYNTHESIS LOGIC END ---

  // Updated to accept List<String> for fromCids
  Future<void> _executeSynthesis(List<String> fromCids, String toCid, Map<String, dynamic> fromH, Map<String, dynamic> toH) async {
    final res = await Api.request("/roster/synthesis", method: "POST", body: {"from": fromCids, "to": toCid});
    if (res['status'] == 200 && res['data'] != null) {
      setState(() {
          synthesisResult = Map<String, dynamic>.from(res['data']);
          synthesisFromHero = fromH; 
          synthesisToHero = toH;   
          showSynthesisResult = true;
          selectedParty = null; 
          
          // Reset mode after successful synth
          _isSynthesisMode = false;
          _synthesisMaterials.clear();
          _synthesisTarget = null;
        }
      );
      _loadRosterCount();
      _loadRoster(page: _currentPage); 
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Synthesis Failed: ${res['error']}")));
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrowMode = constraints.maxWidth < 600;
        
        final bool shouldAutoMinimize = 220 > (constraints.maxWidth * 0.2);
        final bool isCollapsed = _isSidebarCollapsed ?? shouldAutoMinimize;
        
        final Widget content = _buildMainContent(constraints, isNarrowMode);
        final Widget sidebar = _buildSidebar(isCollapsed, isNarrowMode);

        if (isNarrowMode) {
          // --- NARROW LAYOUT ---
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: content,
              ),

              
              if (!_isNarrowSidebarOpen)
                Positioned(
                  left: 21, 
                  top: 21,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card, 
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0,2))]
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => setState(() => _isNarrowSidebarOpen = true),
                    ),
                  ),
                ),

              if (_isNarrowSidebarOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isNarrowSidebarOpen = false),
                        child: Container(color: Colors.black54),
                      ),
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
                          child: sidebar
                        ),
                      )
                    ]
                  )
                )
            ],
          );
        } else {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sidebar,
                const SizedBox(width: 16),
                Expanded(child: content),
              ]
            ),
          );
        }
      }
    );
  }

  Widget _buildSidebar(bool isCollapsed, bool isNarrowMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 50 : 220,
      decoration: isNarrowMode 
        ? BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)) 
        : null,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 50, 
                height: 50,
                child: Center(
                  child: IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () {
                      if (isNarrowMode) {
                        setState(() => _isNarrowSidebarOpen = false);
                      } else {
                        setState(() => _isSidebarCollapsed = !isCollapsed);
                      }
                    }
                  )
                )
              )
            ]
          ),

          const SizedBox(height: 8),

          // --- SYNTHESIS TOGGLE BUTTON START ---
          SizedBox(
            width: double.infinity,
            child: Tooltip(
              message: "Toggle Synthesis Mode",
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSynthesisMode ? Colors.amber[700] : Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: isCollapsed ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: _isSynthesisMode ? 6 : 2,
                ),
                onPressed: _toggleSynthesisMode,
                child: isCollapsed 
                  ? const Icon(Icons.construction, size: 20) 
                  : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.construction, size: 16), SizedBox(width: 8), Text("SYNTHESIS")]
                  )
              ),
            )
          ),
          // --- SYNTHESIS TOGGLE BUTTON END ---

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.text,
                padding: isCollapsed ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () => _showTextInputDialog("Name", "", (v) => _createParty(v)),
              child: isCollapsed 
                ? const Icon(Icons.add, size: 20) 
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.add, size: 16), SizedBox(width: 8), Text("NEW PARTY")]
                )
            )
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              color: Colors.transparent,
              child: ListView.builder(
                itemCount: parties.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, i) {
                  final p = parties[i];
                  final c = partyColors[i % partyColors.length];
                  final selected = (selectedParty != null && selectedParty['pid'] == p['pid']);

                  return InkWell(
                    onTap: () => _selectParty(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 60,
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 50, 
                            alignment: Alignment.center, 
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              width: isCollapsed ? 24 : 12,  
                              height: isCollapsed ? 24 : 12,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: (selected && isCollapsed) 
                                  ? Border.all(color: Colors.white, width: 2) 
                                  : null
                              )
                            )
                          ),

                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isCollapsed ? 0.0 : 1.0,
                              child: isCollapsed
                                ? const SizedBox() 
                                : Text(
                                  p['partyName'] ?? p['pid'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selected ? Colors.white : Colors.grey
                                  )
                                )
                            )
                          ),

                          if (selected && !isCollapsed)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                            onPressed: () => _deleteParty(p['pid'])
                          )
                        ]
                      )
                    )
                  );
                }
              )
            )
          )
        ]
      )
    );
  }

  Widget _buildMainContent(BoxConstraints constraints, bool isNarrowMode) {
    final bool isMobileMode = constraints.maxWidth < 600;

    if (showSynthesisResult && synthesisResult != null) {
      return _buildSynthesisResultView();
    }

    return Column(
      children: [
        if (selectedParty != null) 
          Container(
            height: (constraints.maxWidth < 800)? 190: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12)
            ),
            child: selectedParty == null
              ? const Center(child: Text(""))
              : Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () => _showTextInputDialog("Rename", selectedParty['partyName'] ?? "", (v) => _renameParty(selectedParty['pid'], v)),
                        child: Text(selectedParty['partyName'] ?? "Unknown", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 14, color: Colors.grey)
                    ]),
                  if (hasUnsavedChanges)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text("SAVE CHANGES"),
                      onPressed: _saveFormation)),
                  const SizedBox(height: 12),
                  Expanded(child: HexFormationView(formation: tempFormation, roster: roster, onHeroDrop: _onHeroDroppedOnHex, onHeroRemove: _onHeroRemoved))
                ])
          ),

        const SizedBox(height: 16),
        // Roster header with Synthesis indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 4), child: Text("Roster", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
          ],
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, rosterConstraints) {
              int crossAxisCount = (rosterConstraints.maxWidth / 110).floor();
              if (crossAxisCount > 10) crossAxisCount = 10;
              if (crossAxisCount < 2) crossAxisCount = 2;

              final double spacing = 6.0;
              final double totalSpacing = (crossAxisCount - 1) * spacing;
              final double availableWidth = rosterConstraints.maxWidth - totalSpacing; 
              final double cardWidth = availableWidth / crossAxisCount;
              final double cardHeight = cardWidth / 0.70;

              return Container(
                decoration: BoxDecoration(
                  color: _isSynthesisMode ? Colors.amber.withOpacity(0.05) : Colors.black26, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: _isSynthesisMode ? Colors.amber.withOpacity(0.3) : Colors.white10)
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingRoster 
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                  controller: _rosterScrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final h = roster[i];
                            final cid = h['cid'];
                            Color? color;
                            
                            if (tempFormation.containsKey(cid) && selectedParty != null) {
                              int idx = parties.indexWhere((p) => p['pid'] == selectedParty['pid']);
                              if (idx != -1) color = partyColors[idx % partyColors.length];
                            }
                            else {
                              for (int pIdx = 0; pIdx < parties.length; pIdx++) {
                                if (parties[pIdx]['pid'] != (selectedParty?['pid']) && parties[pIdx]['formation'] != null && (parties[pIdx]['formation'] as Map).containsKey(cid)) {
                                  color = partyColors[pIdx % partyColors.length].withOpacity(0.5);
                                  break;
                                }
                              }
                            }

                            // --- SYNTHESIS HIGHLIGHT LOGIC ---
                            bool isMaterial = _synthesisMaterials.contains(cid);
                            bool isTarget = _synthesisTarget == cid;

                            return _InteractiveDraggableHero(
                              key: ValueKey(cid), 
                              heroData: h,
                              cid: cid,
                              partyColor: color,
                              cardWidth: cardWidth,
                              cardHeight: cardHeight,
                              isMobileMode: isMobileMode,
                              onRename: _renameHero,
                              onDropAccept: _onHeroDroppedOnHero,
                              
                              // New Props
                              isSynthesisMode: _isSynthesisMode,
                              isSynthesisMaterial: isMaterial,
                              isSynthesisTarget: isTarget,
                              onSynthesisTap: () => _onSynthesisHeroTap(cid),
                              onSynthesisSetTarget: () => _onSynthesisHeroSetTarget(cid),
                            );
                          },
                          childCount: roster.length,
                        ),
                      ),
                    ),
                    if (_totalHeroes > 0 || _currentPage > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: _buildCompactPageSelector()),
                      ),
                    )
                  ],
                ),
              );
            }
          )
        )
      ]
    );
  }

  Widget _buildCompactPageSelector() {
    int totalPages = (_totalHeroes / 50).ceil();
    if (totalPages <= 1) return Container();

    bool canGoNext = _currentPage < totalPages || (!_isLoadingRoster && roster.length >= 50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          _buildTinyPageBtn(Icons.chevron_left, 
            enabled: _currentPage > 1 && !_isLoadingRoster, 
            onTap: () => _loadRoster(page: _currentPage - 1)
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              (totalPages <= 1 && _currentPage > 1) 
                ? "Page $_currentPage" 
                : "$_currentPage / $totalPages",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ) ,
          ),

          _buildTinyPageBtn(Icons.chevron_right, 
            enabled: canGoNext,
            onTap: () => _loadRoster(page: _currentPage + 1)
          ),
        ],
      ),
    );
  }

  Widget _buildTinyPageBtn(IconData icon, {required bool enabled, required VoidCallback onTap}) {
    return SizedBox(
      width: 30, height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: enabled ? onTap : null,
        icon: Icon(icon),
        color: Colors.white,
        disabledColor: Colors.white12,
      )
    );
  }

  Widget _buildSynthesisResultView() {
    if (synthesisResult == null || synthesisToHero == null) return const SizedBox.shrink();

    final consumed = synthesisFromHero ?? {};
    final resultData = synthesisResult!['data'] ?? synthesisResult!;

    final afterStats = Map<String, dynamic>.from(resultData['after'] ?? {});

    final oldHero = synthesisToHero!;
    final oldStats = oldHero['stats'] ?? {};

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
                Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("BEFORE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 140, height: 200,
                        child: HeroCard(data: oldHero, onRename: (_, __) {
                          }
                        )
                      )
                    ]
                  )
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Icon(Icons.keyboard_double_arrow_right, color: AppColors.accent, size: 48)
                ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("AFTER", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 160, height: 220,
                      child: HeroCard(data: afterCardData, onRename: (_, __) {
                        }
                      )
                    )
                  ]
                )
              ]
            )
          ),

          const SizedBox(height: 24),

          Container(
            width: 500, 
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildStatRow("Level", oldHero['level'], afterStats['level']),
                const Divider(color: Colors.white10, height: 16),
                _buildStatRow("HP", oldStats['HP'], afterStats['stats']?['HP']),
                _buildStatRow("MP", oldStats['SP'], afterStats['stats']?['SP']), 
                _buildStatRow("AP", oldStats['AP'], afterStats['stats']?['AP']),
                const Divider(color: Colors.white10, height: 16),
                _buildStatRow("STR", oldStats['STR'], afterStats['stats']?['STR']),
                _buildStatRow("VIT", oldStats['VIT'], afterStats['stats']?['VIT']),
                _buildStatRow("INT", oldStats['INT'], afterStats['stats']?['INT']),
                _buildStatRow("DEX", oldStats['DEX'], afterStats['stats']?['DEX']),
                _buildStatRow("AGI", oldStats['AGI'], afterStats['stats']?['AGI']),
                _buildStatRow("LUK", oldStats['LUK'], afterStats['stats']?['LUK'])
              ]
            )
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
                }
              );
              refresh();
            }, 
            child: const Text("CONTINUE")
          )
        ]
      )
    );
  }

  Widget _buildStatRow(String label, dynamic oldVal, dynamic newVal) {
    int o = (oldVal is num) ? oldVal.toInt() : 0;
    int n = (newVal is num) ? newVal.toInt() : o; 

    if (n == 0 && o > 0) n = o;

    int diff = n - o;
    if (diff == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
            Text("$o", style: const TextStyle(color: Colors.white38)),
            const Spacer(),
            const Text("-", style: TextStyle(color: Colors.white10))
          ]
        )
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
            child: Icon(Icons.arrow_right_alt, color: Colors.white24, size: 16)
          ),
          Text("$n", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text("+$diff", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  Map<String, dynamic> _mapSynthesisToCardData(Map<String, dynamic>? statsData, Map<String, dynamic> originalHero) {
    if (statsData == null) return originalHero;

    final stats = statsData['stats'] ?? {};

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
      'stamina': {'max': safeGet(stats['AP'], originalHero['stamina']?['max'])}
    };
  }
}

class _InteractiveDraggableHero extends StatefulWidget {
  final Map<String, dynamic> heroData;
  final String cid;
  final Color? partyColor;
  final double cardWidth;
  final double cardHeight;
  final bool isMobileMode;
  final Future<void> Function(String, String) onRename;
  final Function(String, String) onDropAccept;

  // New Synthesis Props
  final bool isSynthesisMode;
  final bool isSynthesisMaterial;
  final bool isSynthesisTarget;
  final VoidCallback onSynthesisTap;
  final VoidCallback onSynthesisSetTarget;

  const _InteractiveDraggableHero({
    super.key,
    required this.heroData,
    required this.cid,
    required this.partyColor,
    required this.cardWidth,
    required this.cardHeight,
    required this.isMobileMode,
    required this.onRename,
    required this.onDropAccept,
    
    // Default values for standard mode
    this.isSynthesisMode = false,
    this.isSynthesisMaterial = false,
    this.isSynthesisTarget = false,
    required this.onSynthesisTap,
    required this.onSynthesisSetTarget,
  });

  @override
  State<_InteractiveDraggableHero> createState() => _InteractiveDraggableHeroState();
}

class _InteractiveDraggableHeroState extends State<_InteractiveDraggableHero> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // If Synthesis Mode is ON, we disable dragging and use Tap/DoubleTap gestures
    if (widget.isSynthesisMode) {
      return GestureDetector(
        onTap: widget.onSynthesisTap,
        onDoubleTap: widget.onSynthesisSetTarget,
        onLongPress: widget.onSynthesisSetTarget, // Alternative for mobile
        child: Container(
          decoration: BoxDecoration(
            // Green for Target, Red for Material
            border: widget.isSynthesisTarget 
              ? Border.all(color: Colors.greenAccent, width: 4)
              : widget.isSynthesisMaterial 
                  ? Border.all(color: Colors.redAccent, width: 3) 
                  : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.isSynthesisTarget 
              ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)]
              : widget.isSynthesisMaterial
                  ? [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 6)]
                  : null,
          ),
          child: HeroCard(data: widget.heroData, onRename: (_, __) {}, partyColor: widget.partyColor)
        ),
      );
    }

    // Standard Drag and Drop Mode
    return DragTarget<String>(
      onWillAccept: (fromCid) => fromCid != widget.cid,
      onAccept: (fromCid) => widget.onDropAccept(fromCid, widget.cid),
      builder: (context, candidateData, rejectedData) {
        
        final bool isTargeted = candidateData.isNotEmpty; 

        return Listener(
          onPointerDown: (_) => setState(() => _isPressed = true),
          onPointerUp: (_) => setState(() => _isPressed = false),
          onPointerCancel: (_) => setState(() => _isPressed = false),
          child: LongPressDraggable<String>(
            delay: widget.isMobileMode ? const Duration(milliseconds: 300) : const Duration(milliseconds: 60),
            data: widget.cid,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              color: Colors.transparent, 
              child: Container(
                width: widget.cardWidth, 
                height: widget.cardHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: HeroCard(data: widget.heroData, onRename: (_, __) {}, partyColor: widget.partyColor)
              )
            ),
            childWhenDragging: Opacity(
              opacity: 0.3, 
              child: HeroCard(data: widget.heroData, onRename: widget.onRename, partyColor: widget.partyColor)
            ),
            child: Container(
              color: Colors.transparent, 
              child: Container(
                decoration: BoxDecoration(
                  border: _isPressed 
                    ? Border.all(color: Colors.redAccent, width: 2) 
                    : isTargeted 
                      ? Border.all(color: Colors.greenAccent, width: 3) 
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isTargeted ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10)] : null
                ),
                child: HeroCard(data: widget.heroData, onRename: widget.onRename, partyColor: widget.partyColor)
              ),
            )
          ),
        );
      }
    );
  }
}