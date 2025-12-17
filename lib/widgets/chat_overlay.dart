import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:flutter/gestures.dart'; // Required for TapGestureRecognizer
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/chat_service.dart';
import '../core/api.dart'; // Ensure Api is imported

enum ChatMode { minimized, normal, fullscreen }

class ChatOverlay extends StatefulWidget {
  const ChatOverlay({super.key});

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> with SingleTickerProviderStateMixin {
  final ChatService _service = ChatService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  ChatMode _mode = ChatMode.normal;
  String _activeChannelId = 'server';

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChatUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _service.removeListener(_onChatUpdate);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onChatUpdate() {
    if (mounted) {
      setState(() {});
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 50) {
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  void _sendMessage() {
    if (_textCtrl.text.trim().isNotEmpty) {
      _service.sendMessage(_activeChannelId, _textCtrl.text);
      _textCtrl.clear();
      _scrollToBottom();
    }
  }

  // --- NEW: FETCH PLAYER DATA ---
  Future<void> _fetchAndShowMiniProfile(String username) async {
    // 1. Show Loading Indicator
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 2. Request Data
      final res = await Api.request("/player/$username");
      
      // Close Loading Indicator
      if (mounted) Navigator.pop(context);

      if (res != null && res['data'] != null) {
        if (mounted) _showMiniProfileDialog(res['data']);
      } else {
        _showError("Player not found.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Ensure loader is closed
        _showError("Failed to load profile.");
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- NEW: MINI PROFILE DIALOG UI ---
  void _showMiniProfileDialog(Map<String, dynamic> data) {
    final displayName = data['displayName'] ?? "Unknown";
    final userId = data['userId'] ?? "???";
    final isVerified = data['emailVerified'] == true;
    final stats = data['statistic'] ?? {};
    
    final lastSeen = _formatLastSeen(stats['last_seen']?.toString());
    final memberSince = _formatJoinedDate(stats['register_date']?.toString());
    
    final towerFloorRaw = stats['highest_tower_floor']?.toString() ?? "0";
    final int towerFloor = int.tryParse(towerFloorRaw) ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10)
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.accent,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
            const SizedBox(height: 12),
            
            // Name + Verified + Tower Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 if (towerFloor > 10) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.getRarityColor(towerFloor ~/ 10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "$towerFloor",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                Flexible(
                  child: Text(
                    displayName, 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, color: Colors.blueAccent, size: 16)
                ]
              ],
            ),
            
            const SizedBox(height: 4),
            Text("ID: $userId", style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: "monospace")),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            
            // Stats Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDialogStat("Member Since", memberSince),
                _buildDialogStat("Last Seen", lastSeen, highlight: lastSeen == "Online"),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Close", style: TextStyle(color: Colors.white54))
          )
        ],
      )
    );
  }

  Widget _buildDialogStat(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: TextStyle(
            color: highlight ? Colors.greenAccent : Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          )
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = 300;
    double width = 350;
    
    if (_mode == ChatMode.minimized) {
      height = 50; width = 140;
    } else if (_mode == ChatMode.fullscreen) {
      height = MediaQuery.of(context).size.height - 140;
      width = MediaQuery.of(context).size.width - 40;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      margin: const EdgeInsets.only(left: 16, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
      ),
      child: _mode == ChatMode.minimized ? _buildMinimized() : _buildMaximized(),
    );
  }

  Widget _buildMinimized() {
    return InkWell(
      onTap: () => setState(() => _mode = ChatMode.normal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          const Text("Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (!_service.isConnected) 
            const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.wifi_off, size: 12, color: Colors.red))
        ],
      ),
    );
  }

  Widget _buildMaximized() {
    final activeChan = _service.getChannel(_activeChannelId);
    final isGroup = activeChan?.type == 'GROUP';

    return Column(
      children: [
        // --- CHAT HEADER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10))
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_mode == ChatMode.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 20, color: Colors.white70),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => setState(() => _mode = _mode == ChatMode.fullscreen ? ChatMode.normal : ChatMode.fullscreen),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove, size: 20, color: Colors.white70),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => setState(() => _mode = ChatMode.minimized),
              ),
              
              const Spacer(),

              if (isGroup && activeChan != null)
                IconButton(
                  icon: const Icon(Icons.ios_share, size: 18, color: AppColors.accent),
                  tooltip: "Share Invite Code",
                  padding: EdgeInsets.zero, 
                  constraints: const BoxConstraints(),
                  onPressed: () => _showInviteDialog(activeChan.id, activeChan.name),
                ),
              if (isGroup) const SizedBox(width: 12),

              PopupMenuButton<String>(
                initialValue: _activeChannelId,
                color: AppColors.card,
                child: Row(
                  children: [
                    Text(activeChan?.name ?? "Select", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70)
                  ],
                ),
                onSelected: (val) {
                  if (val == '__ADD__') {
                    _showAddGroupDialog();
                  } else {
                    setState(() { _activeChannelId = val; });
                    _scrollToBottom();
                  }
                },
                itemBuilder: (ctx) => [
                  ..._service.channels.map((c) => PopupMenuItem(
                    value: c.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.name, style: const TextStyle(color: Colors.white)),
                        if (c.type == 'GROUP') 
                          InkWell(
                            onTap: () { Navigator.pop(ctx); _service.leaveGroup(c.id); },
                            child: const Icon(Icons.close, size: 14, color: Colors.redAccent)
                          )
                      ]
                    )
                  )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: '__ADD__', child: Row(children: [Icon(Icons.add, size: 16, color: Colors.green), SizedBox(width: 8), Text("Join / Create", style: TextStyle(color: Colors.green))]))
                ],
              ),
            ],
          ),
        ),

        // --- MESSAGE LIST ---
        Expanded(
          child: activeChan == null ? const SizedBox() : ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: activeChan.messages.length,
            itemBuilder: (ctx, i) {
              final msg = activeChan.messages[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12),
                    children: [
                      TextSpan(text: "[${DateFormat('HH:mm').format(msg.timestamp)}] ", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      
                      // UPDATED: Clickable Sender Name
                      TextSpan(
                        text: "${msg.sender}: ", 
                        style: TextStyle(color: _getNameColor(msg.sender), fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            if (msg.sender != "Server" && msg.sender != "Admin") {
                              _fetchAndShowMiniProfile(msg.sender);
                            }
                          }
                      ),
                      
                      TextSpan(text: msg.content, style: const TextStyle(color: Colors.white70)),
                    ]
                  )
                ),
              );
            }
          )
        ),

        // --- INPUT AREA ---
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.white24),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 16, color: AppColors.accent),
                onPressed: _sendMessage,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              )
            ],
          ),
        )
      ],
    );
  }

  Color _getNameColor(String name) {
    if (name == "Admin" || name == "Server") return Colors.redAccent;
    return AppColors.accent;
  }

  void _showAddGroupDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card, 
      title: const Text("Chat Groups", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create New Group", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          TextField(
            controller: nameCtrl, 
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Group Name", labelStyle: TextStyle(color: Colors.grey))
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _service.createGroup(nameCtrl.text); Navigator.pop(ctx); }, 
              child: const Text("Create")
            ),
          ),
          
          const Divider(height: 32, color: Colors.white10),
          
          const Text("Join Existing Group", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          TextField(
            controller: idCtrl, 
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Invite Code / Group ID", labelStyle: TextStyle(color: Colors.grey))
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _service.joinGroup(idCtrl.text); Navigator.pop(ctx); }, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800), 
              child: const Text("Join")
            ),
          ),
        ],
      )
    ));
  }

  void _showInviteDialog(String gid, String groupName) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10)
        ),
        title: const Text("Invite to Group", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Share this code to invite others to\n'$groupName'", 
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.5))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gid, 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.accent),
                    tooltip: "Copy Code",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: gid));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Code copied to clipboard!"), 
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        )
                      );
                    },
                  )
                ],
              )
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Close", style: TextStyle(color: Colors.white54))
          )
        ],
      )
    );
  }

  // --- HELPER FORMATTING FUNCTIONS ---
  
  String _formatJoinedDate(String? dateStr) {
    if (dateStr == null) return "-";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return "$day/$month/${date.year}";
    } catch (e) {
      return "-";
    }
  }

  String _formatLastSeen(String? dateStr) {
    if (dateStr == null) return "Offline";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);

      if (diff.inSeconds < 120) {
        return "Online";
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes} mins ago";
      } else if (diff.inHours < 24) {
        return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
      } else if (diff.inDays < 7) {
        return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
      } else {
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return "$day/$month/${date.year}";
      }
    } catch (e) {
      return "Unknown";
    }
  }
}