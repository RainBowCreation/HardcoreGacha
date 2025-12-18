import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart'; 
import 'package:stomp_dart_client/stomp_dart_client.dart'; 
import '../core/constants.dart';
import '../core/api.dart';

class ChatMessage {
  final String id;
  final String sender;
  final String content;
  final String type; // CHAT, JOIN, LEAVE
  final String targetId; // Channel ID
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.type,
    required this.targetId,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: json['sender'] ?? "Unknown",
      content: json['content'] ?? "",
      type: json['type'] ?? "CHAT",
      targetId: json['targetId'] ?? "global",
      timestamp: DateTime.now(), 
    );
  }

  Map<String, dynamic> toJson() => {
    'sender': sender,
    'content': content,
    'type': type,
    'targetId': targetId,
  };
}

class ChatChannel {
  final String id;   // This acts as the 'gid' or channel identifier
  final String name;
  final String type; // 'SERVER', 'LOCAL', 'GROUP', 'P2P'
  final List<ChatMessage> messages = [];
  bool hasUnread = false;

  ChatChannel({required this.id, required this.name, required this.type});
}

// --- SERVICE ---
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  StompClient? _client;
  bool isConnected = false;
  
  // Channels
  final Map<String, ChatChannel> _channels = {
    'server': ChatChannel(id: 'server', name: 'Server', type: 'SERVER'),
    'local': ChatChannel(id: 'local', name: 'Local', type: 'LOCAL')
  };

  final Map<String, dynamic> _unsubscribeFunctions = {}; 
  
  String? _currentUser;
  
  List<ChatChannel> get channels => _channels.values.toList();
  ChatChannel? getChannel(String id) => _channels[id];

  void connect(String token, String username) {
    _currentUser = username;
    // Prevent double connection if already active
    if (_client != null && _client!.isActive) return;

    final wsUrl = API_ROOT.replaceFirst("http", "ws") + "/ws/chat";

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) => print("WS Error: $error"),
        stompConnectHeaders: {'X-Auth': token},
        webSocketConnectHeaders: {'X-Auth': token},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    isConnected = true;
    notifyListeners();

    // Subscribe to Static Channels
    _subscribe('/topic/server', 'server');
    _subscribe('/topic/local', 'local');
    
    // Fetch and Resubscribe to user's joined groups from Backend
    _restoreJoinedGroups();
  }

  /// Fetches the list of Group IDs the user is part of from GET /chat
  /// Then calls joinGroup(id) to get the name and subscribe.
  Future<void> _restoreJoinedGroups() async {
    try {
      final res = await Api.request("/chat");
      if (res['status'] == 200 && res['data'] != null) {
        final List<dynamic> groupIds = res['data'];
        
        for (var gid in groupIds) {
          await joinGroup(gid.toString());
        }
      }
    } catch (e) {
      print("Error restoring chat groups: $e");
    }
  }

  void _subscribe(String topic, String channelId) {
    if (_client == null) return;

    final unsubscribeFn = _client!.subscribe(
      destination: topic,
      callback: (frame) {
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          final msg = ChatMessage.fromJson(data);
          _addMessage(channelId, msg);
        }
      },
    );

    _unsubscribeFunctions[channelId] = unsubscribeFn;
  }

  void _addMessage(String channelId, ChatMessage msg) {
    if (_channels.containsKey(channelId)) {
      _channels[channelId]!.messages.add(msg);
      _channels[channelId]!.hasUnread = true;
      notifyListeners();
    }
  }

  // SEND MESSAGE
  void sendMessage(String targetId, String content) {
    if (!isConnected || content.trim().isEmpty) return;

    String destination;
    
    if (targetId == 'server') {
      destination = '/app/chat.server';
    } else if (targetId == 'local') {
      destination = '/app/chat.local';
    } else if (targetId == 'p2p') {
      destination = '/app/chat.p2p'; 
    } else {
      // It's a Group (gid)
      destination = '/app/chat.group.$targetId';
    }

    final msg = ChatMessage(
      id: "", 
      sender: _currentUser ?? "Player", 
      content: content, 
      type: "CHAT", 
      targetId: targetId,
      timestamp: DateTime.now()
    );

    _client?.send(
      destination: destination,
      body: jsonEncode(msg.toJson()),
    );
  }

  // GROUP MANAGEMENT
  
  Future<void> createGroup(String name) async {
    final res = await Api.request(
      "/chat/group/create", 
      method: "POST", 
      body: {"name": name} 
    );
    
    if (res['status'] == 200 && res['data'] != null) {
      final gid = res['data']['groupId'];
      _joinGroupLocal(gid, name);
    }
  }

  Future<void> joinGroup(String gid) async {
    final res = await Api.request(
      "/chat/group/join", 
      method: "POST",
      body: {"gid": gid}
    );
    
    if (res['status'] == 200 && res['data'] != null) {
      final name = res['data']['group']['name'] ?? "Group";
      _joinGroupLocal(gid, name);
    }
  }

  void _joinGroupLocal(String gid, String name) {
    if (_channels.containsKey(gid)) return;
    
    _channels[gid] = ChatChannel(id: gid, name: name, type: 'GROUP');
    if (isConnected) {
      _subscribe('/topic/group.$gid', gid);
    }
    notifyListeners();
  }

  Future<void> leaveGroup(String gid) async {
    try {
      await Api.request(
        "/chat/group/leave", 
        method: "POST",
        body: {"gid": gid}
      );
    } catch (e) {
      print("Error leaving group on server: $e");
    }
    
    if (_channels.containsKey(gid)) {
      if (_unsubscribeFunctions.containsKey(gid)) {
        _unsubscribeFunctions[gid](); 
        _unsubscribeFunctions.remove(gid);
      }

      _channels.remove(gid);
      notifyListeners();
    }
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    isConnected = false;
    
    _channels.forEach((key, channel) {
      channel.messages.clear();
      channel.hasUnread = false;
    });

    _channels.removeWhere((key, val) => val.type == 'GROUP');

    _unsubscribeFunctions.clear();
    _currentUser = null;

    notifyListeners();
  }
}