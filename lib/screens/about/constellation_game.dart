import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../components/constellation_painter.dart';

/// Interactive easter egg - Constellation drawing game
/// A playful and hidden feature where users connect stars to create constellations
class ConstellationGame extends StatefulWidget {
  const ConstellationGame({super.key});

  @override
  State<ConstellationGame> createState() => _ConstellationGameState();
}

class _ConstellationGameState extends State<ConstellationGame>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  final List<Offset> _stars = [];
  final List<List<int>> _connections = [];
  int? _selectedStarIndex;

  @override
  void initState() {
    super.initState();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Generate random stars
    _generateStars();
  }

  void _generateStars() {
    final random = math.Random();
    _stars.clear();
    for (int i = 0; i < 15; i++) {
      _stars.add(
        Offset(
          random.nextDouble() * 0.8 + 0.1, // 10-90% of width
          random.nextDouble() * 0.8 + 0.1, // 10-90% of height
        ),
      );
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  void _handleTap(Offset position, Size size) {
    // Find nearest star to tap position
    int? nearestStar;
    double minDistance = double.infinity;

    for (int i = 0; i < _stars.length; i++) {
      final starPos = Offset(
        _stars[i].dx * size.width,
        _stars[i].dy * size.height,
      );
      final distance = (starPos - position).distance;

      if (distance < 50 && distance < minDistance) {
        minDistance = distance;
        nearestStar = i;
      }
    }

    if (nearestStar != null) {
      final star = nearestStar; // Capture as non-nullable int
      setState(() {
        if (_selectedStarIndex == null) {
          // First star selected
          _selectedStarIndex = star;
        } else if (_selectedStarIndex == star) {
          // Same star tapped - deselect
          _selectedStarIndex = null;
        } else {
          // Second star - create connection
          final firstStar = _selectedStarIndex!;
          final connection = <int>[firstStar, star];
          // Check if connection already exists
          final exists = _connections.any(
            (c) =>
                (c[0] == connection[0] && c[1] == connection[1]) ||
                (c[0] == connection[1] && c[1] == connection[0]),
          );
          if (!exists) {
            _connections.add(connection);
          }
          _selectedStarIndex = null;
        }
      });
    }
  }

  void _reset() {
    setState(() {
      _connections.clear();
      _selectedStarIndex = null;
    });
  }

  void _regenerate() {
    setState(() {
      _generateStars();
      _connections.clear();
      _selectedStarIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Interactive canvas
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                _handleTap(localPosition, renderBox.size);
              },
              child: CustomPaint(
                painter: ConstellationPainter(
                  stars: _stars,
                  connections: _connections,
                  selectedStarIndex: _selectedStarIndex,
                  animation: _twinkleController.value,
                ),
              ),
            ),
          ),

          // Close button
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                
                const Spacer(),

                // Instructions
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '星座を描こう！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '星をタップして線でつなぎ、\n自分だけの星座を作りましょう',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('リセット'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _regenerate,
                            icon: const Icon(Icons.star, size: 18),
                            label: const Text('新しい星'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
