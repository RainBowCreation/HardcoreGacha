import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants.dart';

class HeroGrid extends StatelessWidget {
  final List<dynamic> heroes;
  final Function(String, String) onRename;

  const HeroGrid({super.key, required this.heroes, required this.onRename});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        int crossAxisCount = (constraints.maxWidth / 130).floor().clamp(2, 8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.70, 
            crossAxisSpacing: 8,
            mainAxisSpacing: 8
          ),
          itemCount: heroes.length,
          itemBuilder: (ctx, i) =>
          HeroCard(data: heroes[i], onRename: onRename)
        );
      }
    );
  }
}

class HeroCard extends StatelessWidget {
  final dynamic data;
  final Function(String, String) onRename;
  final Color? partyColor; 

  const HeroCard({
    super.key, 
    required this.data, 
    required this.onRename,
    this.partyColor
  });

  @override
  Widget build(BuildContext context) {
    final rarity = data['rarity'] ?? 1;
    final rarityColor = AppColors.getRarityColor(rarity);
    final stats = data['stats'] ?? {};
    final displayName = data['displayName'] ?? data['class'] ?? "Unknown";
    final isDeployed = partyColor != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Container(height: 4, color: rarityColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showRenameDialog(context),
                              child: Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                overflow: TextOverflow.ellipsis
                              )
                            )
                          ),
                          Text(
                            "Lv.${data['level'] ?? 1}",
                            style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)
                          )
                        ]
                      ),
                      Text(
                        "${data['race'] ?? '?'} | ${data['class'] ?? '?'}",
                        style: const TextStyle(fontSize: 8, color: AppColors.textDim),
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 4),
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statBox("HP", data['hp']?['max']),
                          _statBox("MP", data['mana']?['max']),
                          _statBox("AP", data['stamina']?['max'])
                        ]
                      ),
                      // Chart
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Opacity(
                            opacity: isDeployed ? 0.8 : 1.0, 
                            child: _buildChart(stats)
                          )
                        )
                      )
                    ]
                  )
                )
              ),

              // BOTTOM BORDER STRIP (Party Highlight)
              if (isDeployed)
              Container(
                height: 2, 
                color: partyColor,
                alignment: Alignment.center
              )
              else 
              const SizedBox(height: 4)
            ]
          )
        )
      )
    );
  }

  void _showRenameDialog(BuildContext context) {
    final c = TextEditingController(text: data['displayName']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename"),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () {
              onRename(data['cid'], c.text); Navigator.pop(context); }, child: const Text("Save"))
        ]
      )
    );
  }

  Widget _buildChart(Map stats) {
    if (stats.isEmpty) return const Center(child: Icon(Icons.bar_chart, color: Colors.white10));

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 1,
        ticksTextStyle: const TextStyle(fontSize: 0),
        gridBorderData: const BorderSide(color: Colors.white10, width: 1),
        titleTextStyle: const TextStyle(fontSize: 5, color: Colors.grey, height: 1.0),
        titlePositionPercentageOffset: 0.1,
        getTitle: (i, angle) {
          const labels = ['STR', 'VIT', 'INT', 'DEX', 'AGI', 'LUK'];
          if (i >= labels.length) return const RadarChartTitle(text: "");
          final key = labels[i];
          return RadarChartTitle(text: "$key\n${stats[key] ?? 0}");
        },
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.accent.withOpacity(0.2),
            borderColor: AppColors.accent,
            entryRadius: 0,
            dataEntries: [
              RadarEntry(value: (stats['STR'] ?? 0).toDouble()),
              RadarEntry(value: (stats['VIT'] ?? 0).toDouble()),
              RadarEntry(value: (stats['INT'] ?? 0).toDouble()),
              RadarEntry(value: (stats['DEX'] ?? 0).toDouble()),
              RadarEntry(value: (stats['AGI'] ?? 0).toDouble()),
              RadarEntry(value: (stats['LUK'] ?? 0).toDouble())
            ]
          )
        ]
      )
    );
  }

  Widget _statBox(String label, dynamic val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text("${val ?? 0}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))
      ]
    );
  }
}
