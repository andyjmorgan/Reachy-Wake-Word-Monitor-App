import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';

void _audioLog(String msg) {
  final logFile = File('/tmp/reechy_app.log');
  final timestamp = DateTime.now().toIso8601String();
  logFile.writeAsStringSync('$timestamp: AUDIO: $msg\n', mode: FileMode.append, flush: true);
}

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSubscription;
  StreamSubscription? _streamSubscription;
  bool _isMuted = false;
  bool _isRecording = false;
  String? _selectedDeviceId;
  List<InputDevice> _devices = [];
  int _silentPacketCount = 0;
  Function(Int16List)? _currentCallback;

  static const int sampleRate = 16000;
  static const int chunkSamples = 1280; // 80ms at 16kHz
  static const int silentPacketThreshold = 50; // Auto-switch after this many silent packets

  bool get isMuted => _isMuted;
  bool get isRecording => _isRecording;
  String? get selectedDeviceId => _selectedDeviceId;
  List<InputDevice> get devices => _devices;
  bool get isMicSilent => _silentPacketCount >= silentPacketThreshold;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<List<InputDevice>> listDevices() async {
    _devices = await _recorder.listInputDevices();
    return _devices;
  }

  void selectDevice(String? deviceId) {
    _selectedDeviceId = deviceId;
  }

  Future<void> start(void Function(Int16List samples) onAudioData) async {
    _audioLog('start() called, isRecording=$_isRecording, selectedDevice=$_selectedDeviceId');

    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    _audioLog('hasPermission=$hasPermission');
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    _currentCallback = onAudioData;
    _silentPacketCount = 0;
    await _startStreamWithDevice(_selectedDeviceId);
  }

  Future<void> _startStreamWithDevice(String? deviceId) async {
    // Stop any existing stream first
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    if (_isRecording) {
      await _recorder.stop();
    }

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      device: deviceId != null
          ? InputDevice(id: deviceId, label: '')
          : null,
    );

    _audioLog('Starting stream with config: sampleRate=$sampleRate, device=$deviceId');
    final stream = await _recorder.startStream(config);
    _audioLog('Stream started successfully');
    _isRecording = true;

    // Buffer to accumulate audio data
    final buffer = BytesBuilder();

    int packetCount = 0;
    _streamSubscription = stream.listen(
      (data) {
        packetCount++;

        // Check if audio is all zeros
        int nonZeroBytes = 0;
        for (int i = 0; i < data.length; i++) {
          if (data[i] != 0) nonZeroBytes++;
        }

        if (packetCount % 100 == 1) {
          _audioLog('Received packet #$packetCount, size=${data.length} bytes, nonZeroBytes=$nonZeroBytes, muted=$_isMuted');
          if (data.length >= 10) {
            _audioLog('First 10 bytes: ${data.sublist(0, 10)}');
          }
        }

        // Track silent packets to warn user
        if (nonZeroBytes == 0) {
          _silentPacketCount++;
          if (_silentPacketCount == silentPacketThreshold) {
            _audioLog('WARNING: $silentPacketThreshold consecutive silent packets detected!');
            _audioLog('The selected microphone may be muted or not working properly.');
            _audioLog('Try selecting a different microphone from the dropdown.');
          }
        } else {
          if (_silentPacketCount > 0) {
            _audioLog('Audio detected after $_silentPacketCount silent packets');
          }
          _silentPacketCount = 0;
        }

        if (_isMuted) return;

        buffer.add(data);

        // Process when we have enough samples (1280 samples * 2 bytes per sample)
        while (buffer.length >= chunkSamples * 2) {
          final bytes = buffer.takeBytes();
          final chunkBytes = bytes.sublist(0, chunkSamples * 2);

          // Put remaining bytes back in buffer
          if (bytes.length > chunkSamples * 2) {
            buffer.add(bytes.sublist(chunkSamples * 2));
          }

          // Convert bytes to Int16List
          final samples = Int16List.view(Uint8List.fromList(chunkBytes).buffer);
          _currentCallback?.call(samples);
        }
      },
      onError: (error) {
        _audioLog('Audio stream error: $error');
      },
    );
  }

  Future<void> stop() async {
    if (!_isRecording) return;

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _recorder.stop();
    _isRecording = false;
    _silentPacketCount = 0;
  }

  void setMuted(bool muted) {
    _isMuted = muted;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await _streamSubscription?.cancel();
    await stop();
    _recorder.dispose();
  }

  // Calculate audio level (RMS) from samples
  static double calculateLevel(Int16List samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    final rms = (sum / samples.length);
    // Normalize to 0-1 range (32768 is max for 16-bit audio)
    final normalized = rms / (32768 * 32768);
    return normalized.clamp(0.0, 1.0);
  }
}
