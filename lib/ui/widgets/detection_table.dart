import 'package:flutter/material.dart';
import '../../models/detection_event.dart';

class DetectionTable extends StatelessWidget {
  final List<DetectionEvent> detections;
  final VoidCallback? onClear;

  const DetectionTable({
    super.key,
    required this.detections,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF30363D),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DETECTIONS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 1.5,
                  ),
                ),
                if (detections.isNotEmpty && onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: Color(0xFF30363D),
          ),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0D1117),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'CONFIDENCE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table body
          Expanded(
            child: detections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hearing_disabled,
                          size: 48,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No detections yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say "reechy" to trigger detection',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: detections.length,
                    itemBuilder: (context, index) {
                      final detection = detections[index];
                      final isRecent = index == 0 &&
                          DateTime.now().difference(detection.timestamp).inSeconds < 3;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        color: isRecent
                            ? const Color(0xFF3FB950).withOpacity(0.1)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (isRecent)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3FB950),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                detection.formattedTime,
                                style: TextStyle(
                                  color: isRecent
                                      ? const Color(0xFF3FB950)
                                      : Colors.grey[300],
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                detection.confidencePercent,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: isRecent
                                      ? const Color(0xFF3FB950)
                                      : _getConfidenceColor(detection.confidence),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return const Color(0xFF3FB950);
    if (confidence >= 0.7) return const Color(0xFF58A6FF);
    return Colors.grey[400]!;
  }
}
