import 'dart:math' as math;
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final double level;
  final bool isActive;

  const AudioVisualizer({
    super.key,
    required this.level,
    required this.isActive,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _barHeights = List.filled(20, 0.1);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..addListener(_updateBars);
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isActive && _animController.isAnimating) {
      _animController.stop();
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 0.1;
        }
      });
    }
  }

  void _updateBars() {
    if (!widget.isActive) return;

    setState(() {
      for (int i = 0; i < _barHeights.length; i++) {
        // Create a wave-like effect based on audio level
        final baseHeight = widget.level * 0.8;
        final variation = _random.nextDouble() * 0.4;
        final wave = math.sin((i / _barHeights.length) * math.pi * 2 +
                _animController.value * math.pi * 2) *
            0.2;
        _barHeights[i] = (baseHeight + variation + wave).clamp(0.1, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barHeights.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 60 * _barHeights[index],
            decoration: BoxDecoration(
              color: widget.isActive
                  ? const Color(0xFF58A6FF).withOpacity(0.8)
                  : Colors.grey[700],
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
