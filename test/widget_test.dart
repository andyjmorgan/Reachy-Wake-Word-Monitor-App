import 'package:flutter_test/flutter_test.dart';
import 'package:reechy_wakeword_monitor/models/detection_event.dart';

void main() {
  test('DetectionEvent formats correctly', () {
    final event = DetectionEvent(
      timestamp: DateTime(2024, 1, 15, 14, 32, 5),
      confidence: 0.982,
    );

    expect(event.formattedTime, equals('14:32:05'));
    expect(event.confidencePercent, equals('98.2%'));
    expect(event.wakeword, equals('reechy'));
  });
}
