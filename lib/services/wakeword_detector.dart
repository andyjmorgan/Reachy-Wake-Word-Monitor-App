import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import '../models/detection_event.dart';

class WakewordDetector {
  OrtSession? _model;
  double _threshold;
  final Duration cooldownTime;

  DateTime? _lastDetection;
  bool _isInitialized = false;
  int _frameCount = 0;

  final _detectionController = StreamController<DetectionEvent>.broadcast();
  Stream<DetectionEvent> get detectionStream => _detectionController.stream;

  bool get isInitialized => _isInitialized;
  double get threshold => _threshold;

  set threshold(double value) {
    _threshold = value.clamp(0.0, 1.0);
  }

  WakewordDetector({
    double threshold = 0.5,
    this.cooldownTime = const Duration(seconds: 2),
  }) : _threshold = threshold;

  Future<void> initialize(String modelPath) async {
    final sessionOptions = OrtSessionOptions();
    _model = OrtSession.fromFile(File(modelPath), sessionOptions);
    _isInitialized = true;
    _frameCount = 0;
  }

  /// Run inference on features and return confidence score.
  /// Features should be shape [1, 16, 96].
  double predict(Float32List features) {
    if (_model == null || !_isInitialized) {
      throw StateError('Wakeword detector not initialized');
    }

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      features,
      [1, 16, 96],
    );

    final inputs = {_model!.inputNames.first: inputTensor};
    final outputs = _model!.run(OrtRunOptions(), inputs);

    final outputTensor = outputs.first!;
    final outputData = outputTensor.value;

    inputTensor.release();
    outputTensor.release();

    // Extract the confidence score
    double confidence = 0.0;
    if (outputData is List) {
      if (outputData.isNotEmpty) {
        final first = outputData[0];
        if (first is List && first.isNotEmpty) {
          final second = first[0];
          if (second is List && second.isNotEmpty) {
            confidence = (second[0] as num).toDouble();
          } else {
            confidence = (second as num).toDouble();
          }
        } else {
          confidence = (first as num).toDouble();
        }
      }
    } else {
      confidence = (outputData as num).toDouble();
    }

    return confidence;
  }

  /// Process features and emit detection event if wakeword detected.
  /// Returns the confidence score.
  double processFeatures(Float32List features) {
    _frameCount++;

    // Skip first 5 frames during initialization (like Python implementation)
    if (_frameCount < 5) {
      return 0.0;
    }

    final confidence = predict(features);

    // Check threshold and cooldown
    if (confidence >= _threshold) {
      final now = DateTime.now();
      final canDetect = _lastDetection == null ||
          now.difference(_lastDetection!) >= cooldownTime;

      if (canDetect) {
        _lastDetection = now;
        final event = DetectionEvent(
          timestamp: now,
          confidence: confidence,
          wakeword: 'reechy',
        );
        _detectionController.add(event);
      }
    }

    return confidence;
  }

  void reset() {
    _lastDetection = null;
    _frameCount = 0;
  }

  void dispose() {
    _model?.release();
    _model = null;
    _isInitialized = false;
    _detectionController.close();
  }
}
