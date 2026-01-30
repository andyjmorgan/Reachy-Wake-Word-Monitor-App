import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../models/detection_event.dart';
import '../services/audio_service.dart';
import '../services/preprocessor.dart';
import '../services/wakeword_detector.dart';

// Debug logging to file
void debugLog(String msg) {
  final logFile = File('/tmp/reechy_app.log');
  final timestamp = DateTime.now().toIso8601String();
  logFile.writeAsStringSync('$timestamp: $msg\n', mode: FileMode.append, flush: true);
}

enum AppStatus {
  initializing,
  ready,
  listening,
  error,
}

class AppProvider extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  final AudioPreprocessor _preprocessor = AudioPreprocessor();
  late final WakewordDetector _detector;

  AppStatus _status = AppStatus.initializing;
  String? _errorMessage;
  bool _isMuted = false;
  double _audioLevel = 0.0;
  double _currentConfidence = 0.0;
  final List<DetectionEvent> _detections = [];
  StreamSubscription<DetectionEvent>? _detectionSubscription;
  List<InputDevice> _audioDevices = [];
  String? _selectedDeviceId;

  static const int maxDetections = 100;

  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isMuted => _isMuted;
  bool get isListening => _status == AppStatus.listening;
  double get audioLevel => _audioLevel;
  double get currentConfidence => _currentConfidence;
  List<DetectionEvent> get detections => List.unmodifiable(_detections);
  List<InputDevice> get audioDevices => _audioDevices;
  String? get selectedDeviceId => _selectedDeviceId;
  double get threshold => _detector.threshold;
  bool get isMicSilent => _audioService.isMicSilent;

  AppProvider() {
    debugLog('AppProvider constructor called');
    _detector = WakewordDetector(
      threshold: 0.5,
      cooldownTime: const Duration(seconds: 2),
    );
  }

  void setThreshold(double value) {
    _detector.threshold = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    debugLog('initialize() called');
    try {
      _status = AppStatus.initializing;
      notifyListeners();

      // Extract models from assets to temp directory
      final tempDir = await getTemporaryDirectory();
      final modelsDir = Directory(path.join(tempDir.path, 'reechy_models'));
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Copy models from assets
      final melspecPath = await _copyAssetToFile(
        'assets/models/melspectrogram.onnx',
        path.join(modelsDir.path, 'melspectrogram.onnx'),
      );
      final embeddingPath = await _copyAssetToFile(
        'assets/models/embedding_model.onnx',
        path.join(modelsDir.path, 'embedding_model.onnx'),
      );
      final wakewordPath = await _copyAssetToFile(
        'assets/models/reechy_wakeword.onnx',
        path.join(modelsDir.path, 'reechy_wakeword.onnx'),
      );

      // Initialize preprocessor
      debugLog('Initializing preprocessor...');
      await _preprocessor.initialize(melspecPath, embeddingPath);
      debugLog('Preprocessor initialized');

      // Initialize detector
      debugLog('Initializing detector...');
      await _detector.initialize(wakewordPath);
      debugLog('Detector initialized');

      // Subscribe to detection events
      _detectionSubscription = _detector.detectionStream.listen(_onDetection);

      // List audio devices
      debugLog('Listing audio devices...');
      await refreshDevices();
      debugLog('Found ${_audioDevices.length} devices');
      for (final device in _audioDevices) {
        debugLog('  Device: ${device.id} - ${device.label}');
      }

      // Auto-select first device if available
      if (_audioDevices.isNotEmpty) {
        _selectedDeviceId = _audioDevices.first.id;
        _audioService.selectDevice(_selectedDeviceId);
        debugLog('Auto-selected device: $_selectedDeviceId');
      }

      _status = AppStatus.ready;
      debugLog('Status set to ready');
      notifyListeners();

      // Auto-start listening
      debugLog('Auto-starting listening...');
      await startListening();
    } catch (e, stackTrace) {
      debugLog('ERROR during initialization: $e\n$stackTrace');
      _status = AppStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshDevices() async {
    _audioDevices = await _audioService.listDevices();
    notifyListeners();
  }

  Future<void> selectDevice(String? deviceId) async {
    final wasListening = isListening;

    if (wasListening) {
      await stopListening();
    }

    _selectedDeviceId = deviceId;
    _audioService.selectDevice(deviceId);
    notifyListeners();

    if (wasListening) {
      await startListening();
    }
  }

  Future<String> _copyAssetToFile(String assetPath, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return filePath;
  }

  void _onDetection(DetectionEvent event) {
    _detections.insert(0, event);
    if (_detections.length > maxDetections) {
      _detections.removeLast();
    }
    notifyListeners();
  }

  Future<void> startListening() async {
    debugLog('startListening called, status=$_status');
    if (_status != AppStatus.ready && _status != AppStatus.listening) {
      debugLog('Cannot start - wrong status');
      return;
    }

    try {
      debugLog('Calling audioService.start()');
      await _audioService.start(_onAudioData);
      debugLog('audioService.start() completed');
      _status = AppStatus.listening;
      notifyListeners();
    } catch (e) {
      debugLog('Error starting: $e');
      _status = AppStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  int _debugCounter = 0;

  void _onAudioData(Int16List samples) {
    // Debug: Check raw samples
    _debugCounter++;
    if (_debugCounter % 50 == 0) {
      // Check first few sample values
      int nonZeroCount = 0;
      int minSample = 0;
      int maxSample = 0;
      for (int i = 0; i < samples.length; i++) {
        if (samples[i] != 0) nonZeroCount++;
        if (samples[i] < minSample) minSample = samples[i];
        if (samples[i] > maxSample) maxSample = samples[i];
      }
      debugLog('RAW SAMPLES: len=${samples.length}, nonZero=$nonZeroCount, min=$minSample, max=$maxSample, first5=${samples.take(5).toList()}');
    }

    // Calculate audio level
    _audioLevel = AudioService.calculateLevel(samples);

    // Process through preprocessor
    _preprocessor.processAudioChunk(samples);

    // Get features and run detection
    final features = _preprocessor.getFeatures();

    // Debug: check features
    if (_debugCounter % 50 == 0) {
      // Check if features are all zeros
      double sum = 0;
      for (int i = 0; i < features.length; i++) {
        sum += features[i].abs();
      }
      debugLog('audioLevel=$_audioLevel, featuresSum=$sum, featuresLen=${features.length}');
    }

    _currentConfidence = _detector.processFeatures(features);

    // Debug: print confidence when it's above a small threshold
    if (_currentConfidence > 0.01) {
      debugLog('Confidence: ${(_currentConfidence * 100).toStringAsFixed(2)}%');
    }

    notifyListeners();
  }

  Future<void> stopListening() async {
    await _audioService.stop();
    _status = AppStatus.ready;
    _audioLevel = 0.0;
    _currentConfidence = 0.0;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _audioService.setMuted(_isMuted);
    if (_isMuted) {
      _audioLevel = 0.0;
      _currentConfidence = 0.0;
    }
    notifyListeners();
  }

  void clearDetections() {
    _detections.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _detectionSubscription?.cancel();
    _audioService.dispose();
    _preprocessor.dispose();
    _detector.dispose();
    super.dispose();
  }
}
