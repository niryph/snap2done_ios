import 'dart:async';
import 'package:record/record.dart';

class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._();
  static AudioRecorderService get instance => _instance;
  
  late final AudioRecorder _recorder;
  bool _isRecorderInitialized = false;
  
  AudioRecorderService._() {
    _recorder = AudioRecorder();
  }

  Future<void> _initializeRecorder() async {
    if (!_isRecorderInitialized) {
      _isRecorderInitialized = true;
    }
  }

  Future<bool> hasPermission() async {
    await _initializeRecorder();
    return await _recorder.hasPermission();
  }

  Future<void> start({
    required String path,
    required AudioEncoder encoder,
    required int bitRate,
    required int samplingRate,
  }) async {
    await _initializeRecorder();
    final config = RecordConfig(
      encoder: encoder,
      bitRate: bitRate,
      sampleRate: samplingRate,
    );
    await _recorder.start(config, path: path);
  }

  Future<String?> stop() async {
    return await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    _isRecorderInitialized = false;
  }
} 