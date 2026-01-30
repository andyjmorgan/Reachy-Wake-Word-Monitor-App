import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';

/// Audio preprocessor that computes mel-spectrograms and embeddings
/// matching the Python openWakeWord implementation exactly.
class AudioPreprocessor {
  OrtSession? _melspecModel;
  OrtSession? _embeddingModel;

  // Buffers matching Python implementation
  final Queue<double> _rawDataBuffer = Queue<double>();
  List<List<double>> _melspectrogramBuffer = [];
  List<List<double>> _featureBuffer = [];

  int _accumulatedSamples = 0;
  List<double> _rawDataRemainder = [];

  static const int sampleRate = 16000;
  static const int chunkSamples = 1280;
  static const int maxBufferSeconds = 10;
  static const int melspectrogramMaxLen = 10 * 97; // ~10 seconds
  static const int featureBufferMaxLen = 120; // ~10 seconds

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(String melspecModelPath, String embeddingModelPath) async {
    OrtEnv.instance.init();

    final sessionOptions = OrtSessionOptions();

    _melspecModel = OrtSession.fromFile(File(melspecModelPath), sessionOptions);
    _embeddingModel = OrtSession.fromFile(File(embeddingModelPath), sessionOptions);

    // Initialize buffers
    _melspectrogramBuffer = List.generate(76, (_) => List.filled(32, 1.0));

    // Initialize feature buffer with random data (like Python implementation)
    await _initializeFeatureBuffer();

    _isInitialized = true;
  }

  Future<void> _initializeFeatureBuffer() async {
    // Generate 4 seconds of random audio like Python does
    final randomAudio = Int16List(sampleRate * 4);
    for (int i = 0; i < randomAudio.length; i++) {
      randomAudio[i] = ((i * 7 + 13) % 2001) - 1000; // Pseudo-random pattern
    }
    _featureBuffer = await _getEmbeddings(randomAudio);
  }

  Float32List _getMelspectrogram(List<double> audioData) {
    if (_melspecModel == null) {
      throw StateError('Preprocessor not initialized');
    }

    // Convert to Float32List and add batch dimension
    final inputData = Float32List.fromList(audioData.map((x) => x.toDouble()).toList());
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, inputData.length],
    );

    final inputs = {'input': inputTensor};
    final outputs = _melspecModel!.run(OrtRunOptions(), inputs);

    final outputTensor = outputs.first!;
    final outputData = outputTensor.value;

    inputTensor.release();
    outputTensor.release();

    // Extract and transform: spec = spec/10 + 2
    // Handle different output shapes from ONNX model
    final List<double> flatValues = [];

    void extractValues(dynamic data) {
      if (data is num) {
        flatValues.add(data.toDouble() / 10.0 + 2.0);
      } else if (data is List) {
        for (final item in data) {
          extractValues(item);
        }
      }
    }

    extractValues(outputData);

    return Float32List.fromList(flatValues);
  }

  List<double> _getEmbeddingFromMelspec(List<List<double>> melspec) {
    if (_embeddingModel == null) {
      throw StateError('Preprocessor not initialized');
    }

    // Flatten melspec and add batch dimension [1, 76, 32, 1]
    final inputData = Float32List(76 * 32);
    int idx = 0;
    for (int i = 0; i < 76 && i < melspec.length; i++) {
      for (int j = 0; j < 32 && j < melspec[i].length; j++) {
        inputData[idx++] = melspec[i][j];
      }
    }

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 76, 32, 1],
    );

    final inputs = {'input_1': inputTensor};
    final outputs = _embeddingModel!.run(OrtRunOptions(), inputs);

    final outputTensor = outputs.first!;
    final outputData = outputTensor.value;

    inputTensor.release();
    outputTensor.release();

    // Extract 96-dimensional embedding - handle nested lists
    final embedding = <double>[];

    void extractValues(dynamic data) {
      if (data is num) {
        embedding.add(data.toDouble());
      } else if (data is List) {
        for (final item in data) {
          extractValues(item);
        }
      }
    }

    extractValues(outputData);

    // Take only first 96 values if we got more
    return embedding.take(96).toList();
  }

  Future<List<List<double>>> _getEmbeddings(Int16List audioData) async {
    // Convert to double
    final audioDouble = audioData.map((x) => x.toDouble()).toList();

    // Get melspectrogram
    final spec = _getMelspectrogram(audioDouble);

    // Convert to 2D list (frames x 32 mel bins)
    final numFrames = spec.length ~/ 32;
    final melspec = <List<double>>[];
    for (int i = 0; i < numFrames; i++) {
      melspec.add(List.generate(32, (j) => spec[i * 32 + j]));
    }

    // Window with size 76, step 8
    final embeddings = <List<double>>[];
    for (int i = 0; i < melspec.length; i += 8) {
      if (i + 76 <= melspec.length) {
        final window = melspec.sublist(i, i + 76);
        final embedding = _getEmbeddingFromMelspec(window);
        if (embedding.length == 96) {
          embeddings.add(embedding);
        }
      }
    }

    return embeddings;
  }

  void _bufferRawData(List<double> data) {
    for (final sample in data) {
      _rawDataBuffer.add(sample);
      if (_rawDataBuffer.length > sampleRate * maxBufferSeconds) {
        _rawDataBuffer.removeFirst();
      }
    }
  }

  void _streamingMelspectrogram(int nSamples) {
    if (_rawDataBuffer.length < 400) {
      return;
    }

    // Get last n_samples + context from buffer
    final contextSamples = nSamples + 160 * 3;
    final bufferList = _rawDataBuffer.toList();
    final startIdx = (bufferList.length - contextSamples).clamp(0, bufferList.length);
    final audioData = bufferList.sublist(startIdx);

    // Get melspectrogram
    final spec = _getMelspectrogram(audioData);

    // Convert to 2D and append to buffer
    final numFrames = spec.length ~/ 32;
    for (int i = 0; i < numFrames; i++) {
      _melspectrogramBuffer.add(List.generate(32, (j) => spec[i * 32 + j]));
    }

    // Trim buffer if too long
    if (_melspectrogramBuffer.length > melspectrogramMaxLen) {
      _melspectrogramBuffer = _melspectrogramBuffer.sublist(
        _melspectrogramBuffer.length - melspectrogramMaxLen,
      );
    }
  }

  /// Process audio chunk and update feature buffer.
  /// Returns number of processed samples.
  int processAudioChunk(Int16List audioData) {
    if (!_isInitialized) return 0;

    // Convert to double
    var x = audioData.map((s) => s.toDouble()).toList();
    int processedSamples = 0;

    // Handle remainder from previous chunk
    if (_rawDataRemainder.isNotEmpty) {
      x = [..._rawDataRemainder, ...x];
      _rawDataRemainder = [];
    }

    if (_accumulatedSamples + x.length >= chunkSamples) {
      final remainder = (_accumulatedSamples + x.length) % chunkSamples;
      if (remainder != 0) {
        final evenChunks = x.sublist(0, x.length - remainder);
        _bufferRawData(evenChunks);
        _accumulatedSamples += evenChunks.length;
        _rawDataRemainder = x.sublist(x.length - remainder);
      } else {
        _bufferRawData(x);
        _accumulatedSamples += x.length;
        _rawDataRemainder = [];
      }
    } else {
      _accumulatedSamples += x.length;
      _bufferRawData(x);
    }

    // Calculate melspectrogram when minimum samples accumulated
    if (_accumulatedSamples >= chunkSamples && _accumulatedSamples % chunkSamples == 0) {
      _streamingMelspectrogram(_accumulatedSamples);

      // Calculate new embeddings
      for (int i = (_accumulatedSamples ~/ chunkSamples) - 1; i >= 0; i--) {
        final ndx = -8 * i;  // Negative offset from end (0 = last frame)

        final endNdx = (_melspectrogramBuffer.length + ndx).clamp(76, _melspectrogramBuffer.length);
        final startNdx = endNdx - 76;

        if (endNdx - startNdx == 76) {
          final window = _melspectrogramBuffer.sublist(startNdx, endNdx);
          final embedding = _getEmbeddingFromMelspec(window);
          if (embedding.length == 96) {
            _featureBuffer.add(embedding);
          }
        }
      }

      processedSamples = _accumulatedSamples;
      _accumulatedSamples = 0;
    }

    // Trim feature buffer
    if (_featureBuffer.length > featureBufferMaxLen) {
      _featureBuffer = _featureBuffer.sublist(_featureBuffer.length - featureBufferMaxLen);
    }

    return processedSamples != 0 ? processedSamples : _accumulatedSamples;
  }

  /// Get features for wakeword model [1, 16, 96]
  Float32List getFeatures({int nFrames = 16}) {
    if (_featureBuffer.length < nFrames) {
      return Float32List(nFrames * 96); // Return zeros if not enough data
    }

    final features = Float32List(nFrames * 96);
    final startIdx = _featureBuffer.length - nFrames;

    int idx = 0;
    for (int i = startIdx; i < _featureBuffer.length; i++) {
      for (int j = 0; j < 96 && j < _featureBuffer[i].length; j++) {
        features[idx++] = _featureBuffer[i][j];
      }
    }

    return features;
  }

  void reset() {
    _rawDataBuffer.clear();
    _melspectrogramBuffer = List.generate(76, (_) => List.filled(32, 1.0));
    _accumulatedSamples = 0;
    _rawDataRemainder = [];
    _initializeFeatureBuffer();
  }

  void dispose() {
    _melspecModel?.release();
    _embeddingModel?.release();
    _melspecModel = null;
    _embeddingModel = null;
    _isInitialized = false;
  }
}
