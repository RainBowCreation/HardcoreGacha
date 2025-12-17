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
  bool isServerOnline = false;
  int onlinePlayers = 0;
  Timer? _statusTimer;
  
  final GlobalKey<LobbyScreenState> _lobbyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initChat();
    _checkServerStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _checkServerStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    ChatService().disconnect();
    super.dispose();
  }

  Future<void> _initChat() async {
    if (Api.token == null) return;

    String username = "Player";
    try {
      final res = await Api.request("/player"); 
      if (res['data'] != null) {
        username = res['data']['displayName'] ?? res['data']['username'] ?? "Player";
      }
    } catch (e) {
      print("Failed to fetch profile for chat init: $e");
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            text: "HG ", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20), 
            children: [
              TextSpan(text: "CLIENT", style: TextStyle(color: AppColors.accent))
            ]
          )
        ),
        backgroundColor: Colors.black54,
        actions: [
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
                  isServerOnline ? "$onlinePlayers Online" : "Offline", 
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _viewIndex,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        onTap: (i) {
          setState(() {
            _viewIndex = i;
            if (i == 1) {
              _lobbyKey.currentState?.refresh();
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "GACHA"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "LOBBY"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "PROFILE"),
        ]
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _viewIndex,
            children: [
              const GachaScreen(),
              LobbyScreen(key: _lobbyKey),
              const ProfileScreen(),
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