import 'package:flutter/material.dart';

class StatusIndicator extends StatefulWidget {
  final bool isListening;
  final bool isMuted;
  final double confidence;

  const StatusIndicator({
    super.key,
    required this.isListening,
    required this.isMuted,
    required this.confidence,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !widget.isMuted) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    if (widget.isMuted) return Colors.grey;
    if (!widget.isListening) return Colors.grey;
    if (widget.confidence >= 0.5) return const Color(0xFF3FB950);
    return const Color(0xFF58A6FF);
  }

  String get _statusText {
    if (widget.isMuted) return 'MUTED';
    if (!widget.isListening) return 'READY';
    if (widget.confidence >= 0.5) return 'DETECTED!';
    return 'LISTENING...';
  }

  IconData get _statusIcon {
    if (widget.isMuted) return Icons.mic_off;
    if (!widget.isListening) return Icons.mic_none;
    if (widget.confidence >= 0.5) return Icons.check_circle;
    return Icons.mic;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isListening && !widget.isMuted
              ? _pulseAnimation.value
              : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _statusColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon,
                  size: 48,
                  color: _statusColor,
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                    letterSpacing: 2,
                  ),
                ),
                if (widget.isListening && !widget.isMuted) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(widget.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
