import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'hero_card.dart';

class HexFormationView extends StatelessWidget {
  final Map<String, List<int>> formation;
  final List<dynamic> roster;
  final Function(String cid, int q, int r) onHeroDrop;
  final Function(String cid) onHeroRemove;

  const HexFormationView({
    super.key, 
    required this.formation, 
    required this.roster,
    required this.onHeroDrop,
    required this.onHeroRemove,
  });

  @override
  Widget build(BuildContext context) {
    final coords = [
      const Point(0, 0), const Point(0, -1), const Point(1, -1),
      const Point(1, 0), const Point(0, 1), const Point(-1, 1), const Point(-1, 0)
    ];

    const double hexSize = 28.0; 
    
    // Correct Hexagon Aspect Ratio: Width = sqrt(3) * size, Height = 2 * size
    final double itemWidth = sqrt(3) * hexSize;
    final double itemHeight = 2.0 * hexSize;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Grid Background
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: HexGridPainter(
                formation: formation, 
                roster: roster, 
                centerOffset: center, 
                hexSize: hexSize
              ),
            ),
            
            // 2. Interactive Tokens
            ...coords.map((p) {
              double x = center.dx + hexSize * sqrt(3) * (p.x + p.y / 2);
              double y = center.dy + hexSize * 1.5 * p.y;
              
              String? occupantCid;
              dynamic occupantHero;
              
              formation.forEach((cid, pos) {
                if (pos[0] == p.x && pos[1] == p.y) {
                  occupantCid = cid;
                  occupantHero = roster.firstWhere((h) => h['cid'] == cid, orElse: () => null);
                }
              });

              return Positioned(
                left: x - itemWidth / 2,
                top: y - itemHeight / 2,
                child: DragTarget<String>(
                  onWillAccept: (cid) => true,
                  onAccept: (cid) => onHeroDrop(cid, p.x.toInt(), p.y.toInt()),
                  builder: (context, candidateData, rejectedData) {
                    bool isHovering = candidateData.isNotEmpty;
                    
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // A. Drop Zone (Correct Aspect Ratio)
                        ClipPath(
                          clipper: HexagonClipper(),
                          child: Container(
                            width: itemWidth, 
                            height: itemHeight,
                            color: isHovering ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.01),
                          ),
                        ),

                        // B. Hero Token
                        if (occupantCid != null)
                          Draggable<String>(
                            data: occupantCid,
                            onDraggableCanceled: (_, __) => onHeroRemove(occupantCid!),
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 100, height: 140,
                                child: HeroCard(
                                  data: occupantHero ?? {'cid': occupantCid}, 
                                  onRename: (_,__) {}, 
                                  partyColor: AppColors.getRarityColor(1)
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.0, 
                              child: _buildHexToken(itemWidth, itemHeight, occupantHero),
                            ),
                            child: _buildHexToken(itemWidth, itemHeight, occupantHero),
                          ),
                      ],
                    );
                  },
                ),
              );
            }).toList()
          ],
        );
      }
    );
  }

  Widget _buildHexToken(double w, double h, dynamic hero) {
    String label = hero != null ? (hero['displayName'] ?? hero['class']) : "Unknown";
    int lvl = hero != null ? (hero['level'] ?? 1) : 1;
    
    // Scale slightly down to fit inside the grid lines
    return Transform.scale(
      scale: 0.9,
      child: ClipPath(
        clipper: HexagonClipper(),
        child: Container(
          width: w,
          height: h,
          color: AppColors.accent,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Lv.$lvl", style: const TextStyle(fontSize: 8, color: Colors.white70, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      label, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ),
                ],
              ),
              Container(decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.3), width: 1))),
            ],
          ),
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w / 2, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w / 2, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexGridPainter extends CustomPainter {
  final Map<String, List<int>> formation;
  final List<dynamic> roster; 
  final Offset centerOffset;
  final double hexSize;

  HexGridPainter({required this.formation, required this.roster, required this.centerOffset, required this.hexSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOffset;
    final paintStroke = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2;
    
    final coords = [
      const Point(0, 0), const Point(0, -1), const Point(1, -1),
      const Point(1, 0), const Point(0, 1), const Point(-1, 1), const Point(-1, 0)
    ];

    for (var p in coords) {
      double x = center.dx + hexSize * sqrt(3) * (p.x + p.y / 2);
      double y = center.dy + hexSize * 1.5 * p.y;
      
      var path = Path();
      for (int i = 0; i < 6; i++) {
        double angle = pi / 3 * i + pi / 6;
        double hx = x + hexSize * cos(angle);
        double hy = y + hexSize * sin(angle);
        if (i == 0) path.moveTo(hx, hy); else path.lineTo(hx, hy);
      }
      path.close();
      canvas.drawPath(path, paintStroke);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}