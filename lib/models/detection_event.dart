class DetectionEvent {
  final DateTime timestamp;
  final double confidence;
  final String wakeword;

  const DetectionEvent({
    required this.timestamp,
    required this.confidence,
    this.wakeword = 'reechy',
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
