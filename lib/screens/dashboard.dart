import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';
import '../services/chat_service.dart';
import '../widgets/chat_overlay.dart'; 

import 'gacha_screen.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';

class MainDashboard extends StatefulWidget {
  final VoidCallback onLogout;
  const MainDashboard({super.key, required this.onLogout});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _viewIndex = 0;
  
  // Server Status
  bool isServerOnline = false;
  int onlinePlayers = 0;
  Timer? _statusTimer;

  // Player Data
  Map<String, dynamic>? playerData;
  bool _loadingProfile = false;
  
  final GlobalKey<LobbyScreenState> _lobbyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkServerStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkServerStatus();
      _loadProfile(silent: true); 
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    ChatService().disconnect();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) setState(() => _loadingProfile = true);
    try {
      final res = await Api.request("/player"); 
      if (mounted) {
        setState(() {
          if (!silent) _loadingProfile = false;
          if (res['data'] != null) {
            playerData = res['data'];
            _initChat(playerData!['displayName'] ?? playerData!['username']);
          }
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      if (mounted && !silent) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _initChat(String username) async {
    if (Api.token == null) return;
    ChatService().connect(Api.token!, username);
  }

  Future<void> _checkServerStatus() async {
    try {
      final healthRes = await Api.request("/health", isV1: false);
      final isOnline = healthRes['message'] == "ok";
      int players = onlinePlayers;
      if (isOnline) {
        final infoRes = await Api.request("/serverinfo", isV1: false);
        if (infoRes['data'] != null) {
          players = infoRes['data']['online_players'] ?? 0;
        }
      }
      if (mounted) setState(() { isServerOnline = isOnline; onlinePlayers = players; });
    } catch (e) {
      if (mounted) setState(() => isServerOnline = false);
    }
  }

  String _formatNum(int num) {
    if (num >= 1000000) {
      return "${(num / 1000000).toStringAsFixed(1)}M";
    }
    if (num >= 1000) {
      return "${(num / 1000).toStringAsFixed(1)}k";
    }
    return "$num";
  }

  @override
  Widget build(BuildContext context) {
    final currency = playerData?['currency'] ?? {};
    final int gems = currency['gem'] ?? 0;
    final int coins = currency['coin'] ?? 0;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 600;
    final bool isMini = screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: isMini? null : RichText(
          text: const TextSpan(
            text: "Hardcore ", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20), 
            children: [
              TextSpan(text: "Gacha", style: TextStyle(color: AppColors.accent))
            ]
          )
        ),
        backgroundColor: Colors.black54,
        actions: [
          // MINI CURRENCY DISPLAY
          if (playerData != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12)
              ),
              child: Row(
                children: [
                  Text(
                    isSmall ? _formatNum(gems) : "$gems", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)
                  ),
                  const SizedBox(width: 4),
                  const Icon(AppIcons.gem, size: 14, color: AppColors.gem),
                  const SizedBox(width: 12),
                  Text(
                    isSmall ? _formatNum(coins) : "$coins", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)
                  ),
                  const SizedBox(width: 4),
                  const Icon(AppIcons.coin, size: 14, color: AppColors.coin),
                ],
              ),
            ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black26, 
              borderRadius: BorderRadius.circular(20), 
              border: Border.all(color: Colors.white10)
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8, 
                  decoration: BoxDecoration(
                    color: isServerOnline ? Colors.greenAccent : Colors.redAccent, 
                    shape: BoxShape.circle, 
                    boxShadow: [
                      BoxShadow(
                        color: (isServerOnline ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5), 
                        blurRadius: 6, 
                        spreadRadius: 1
                      )
                    ]
                  )
                ),
                const SizedBox(width: 8),
                Text(
                  isServerOnline 
                    ? "${isSmall ? _formatNum(onlinePlayers) : onlinePlayers}${isSmall ? '' : ' Online'}" 
                    : "Offline", 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)
                )
              ]
            )
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red), 
            onPressed: widget.onLogout
          )
        ]
      ),
      bottomNavigationBar: SizedBox(
        height: isSmall ? 40 : 60,
        child: BottomNavigationBar(
          currentIndex: _viewIndex,
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textDim,
          
          showSelectedLabels: !isSmall, 
          showUnselectedLabels: !isSmall,
          selectedFontSize: isSmall ? 0 : 14,
          unselectedFontSize: isSmall ? 0 : 12,
          iconSize: isSmall ? 20 : 24,

          onTap: (i) {
            setState(() {
              _viewIndex = i;
              if (i == 1) {
                _lobbyKey.currentState?.refresh();
              }
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.store), label: "Store"),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "LOBBY"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "PROFILE"),
          ]
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _viewIndex,
            children: [
              const GachaScreen(),
              LobbyScreen(key: _lobbyKey),
              ProfileScreen(
                playerData: playerData, 
                isLoading: _loadingProfile,
                onRefresh: _loadProfile
              ),
            ]
          ),

          const Positioned(
            left: 0,
            bottom: 0,
            child: ChatOverlay()
          )
        ],
      )
    );
  }
}