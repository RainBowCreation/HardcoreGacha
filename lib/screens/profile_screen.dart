import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = false;
  Map<String, dynamic>? playerData;
  Timer? _refreshTimer;
  
  // Verification State
  bool _sendingVerification = false;
  DateTime? _verificationEndTime;
  Timer? _countdownTimer;
  String _countdownText = "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Auto-refresh every 1 minute (silent update)
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _loadProfile(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    
    try {
      final res = await Api.request("/player"); 
      if (mounted) {
        setState(() {
          if (!silent) loading = false;
          if (res['data'] != null) {
            playerData = res['data'];
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _requestVerification() async {
    if (_sendingVerification) return;

    setState(() => _sendingVerification = true);

    try {
      // POST request to /mail/validate
      final res = await Api.request("/mail/validate", method: "POST");
      
      if (mounted && res != null && res['expireTime'] != null) {
        final expireTimeStr = res['expireTime'];
        final expireTime = DateTime.parse(expireTimeStr).toLocal();
        _startCooldown(expireTime);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent! Check your inbox.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send email: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  void _startCooldown(DateTime expireTime) {
    _verificationEndTime = expireTime;
    _updateCountdown(); // Update immediately

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCountdown();
      } else {
        timer.cancel();
      }
    });
  }

  void _updateCountdown() {
    if (_verificationEndTime == null) return;

    final now = DateTime.now();
    final diff = _verificationEndTime!.difference(now);

    setState(() {
      if (diff.isNegative) {
        _countdownTimer?.cancel();
        _verificationEndTime = null;
        _countdownText = "";
      } else {
        final minutes = diff.inMinutes.toString().padLeft(1, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
        _countdownText = "$minutes:$seconds";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading && playerData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (playerData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Failed to load profile", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProfile(), 
              child: const Text("Retry")
            )
          ],
        )
      );
    }

    final currency = playerData!['currency'] ?? {};
    final stats = Map<String, dynamic>.from(playerData!['statistic'] ?? {});
    
    // Extract special stats
    final String? lastSeenRaw = stats.remove('last_seen')?.toString();
    final String? registerDateRaw = stats.remove('register_date')?.toString();
    final String? towerFloorRaw = stats.remove('highest_tower_floor')?.toString();
    final int towerFloor = int.tryParse(towerFloorRaw ?? "0") ?? 0;

    final username = playerData!['username'] ?? "Unknown";
    final displayName = playerData!['displayName'] ?? username;
    final email = playerData!['email'] ?? "";
    final userId = playerData!['userId'] ?? "";
    final bool isVerified = playerData!['emailVerified'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Row
                      Row(
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              displayName, 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18),
                          ]
                        ],
                      ),
                      
                      const SizedBox(height: 4),

                      // Email Row + Verify Button
                      if (email.isNotEmpty)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                            if (!isVerified) 
                              SizedBox(
                                height: 24,
                                child: _verificationEndTime != null
                                  ? OutlinedButton(
                                      onPressed: null, // Disabled
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        side: BorderSide(color: Colors.white12),
                                      ),
                                      child: Text(
                                        "Sent ($_countdownText)", 
                                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _sendingVerification ? null : _requestVerification,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: _sendingVerification 
                                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text("Verify", style: TextStyle(fontSize: 10, color: Colors.white)),
                                    ),
                              ),
                          ],
                        ),

                      const SizedBox(height: 6),
                      
                      // ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text("ID: $userId", style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: "monospace"))
                      ),

                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),

                      // Member Since & Last Seen
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniInfo("Member Since", _formatJoinedDate(registerDateRaw)),
                          _buildMiniInfo("Last Seen", _formatLastSeen(lastSeenRaw), isHighlight: true),
                        ],
                      )
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white24),
                  onPressed: () => _loadProfile(),
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          // CURRENCY ROW
          Row(
            children: [
              Expanded(child: _buildCurrencyCard("Gems", currency['gem'] ?? 0, Icons.diamond, const Color(0xFF29B6F6))),
              const SizedBox(width: 16),
              Expanded(child: _buildCurrencyCard("Coins", currency['coin'] ?? 0, Icons.monetization_on, const Color(0xFFFFCA28))),
            ],
          ),

          const SizedBox(height: 24),

          // STATISTICS SECTION
          const Text("STATISTICS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: stats.isEmpty 
              ? const Center(child: Text("No additional statistics", style: TextStyle(color: Colors.grey)))
              : Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: stats.entries.map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            _formatKey(entry.key),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "${entry.value}",
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value, 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.w600, 
            color: isHighlight && value == "Online" ? Colors.greenAccent : Colors.white
          )
        ),
      ],
    );
  }

  Widget _buildCurrencyCard(String label, num value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$value", 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll("_", " ").split(" ").map((str) {
      if (str.isEmpty) return "";
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(" ");
  }

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