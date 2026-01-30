import 'package:flutter/material.dart';

class MuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onPressed;

  const MuteButton({
    super.key,
    required this.isMuted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          isMuted ? Icons.mic_off : Icons.mic,
          size: 24,
        ),
        label: Text(
          isMuted ? 'UNMUTE' : 'MUTE',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isMuted
              ? const Color(0xFF21262D)
              : const Color(0xFF58A6FF),
          foregroundColor: isMuted
              ? Colors.grey[400]
              : Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
