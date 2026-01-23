/// 音频仓储实现
/// 使用 record 包进行音频录制

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/audio_repository.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  @override
  Future<bool> checkPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<bool> startRecording() async {
    try {
      // 检查权限
      if (!await _recorder.hasPermission()) {
        return false;
      }

      // 生成录音文件路径
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/audio_$timestamp.m4a';

      // 配置录音参数
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC 编码
        sampleRate: 16000, // 16kHz
        bitRate: 128000, // 128kbps
        numChannels: 1, // 单声道
      );

      // 开始录音
      await _recorder.start(config, path: path);
      _recordingStartTime = DateTime.now();
      _isRecording = true;

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _recordingStartTime = null;
      _isRecording = false;
      return path;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> pauseRecording() async {
    await _recorder.pause();
  }

  @override
  Future<void> resumeRecording() async {
    await _recorder.resume();
  }

  @override
  Future<void> cancelRecording() async {
    await _recorder.cancel();
    _recordingStartTime = null;
    _isRecording = false;
  }

  @override
  bool isRecording() {
    return _isRecording;
  }

  @override
  double getCurrentDuration() {
    if (_recordingStartTime == null) {
      return 0.0;
    }
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;
  }

  @override
  Future<String> saveAudioFile(String tempPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${directory.path}/recordings');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = tempPath.contains('.') ? tempPath.split('.').last : 'm4a';
    final targetPath = '${targetDir.path}/audio_$timestamp.$ext';
    await File(tempPath).copy(targetPath);
    return targetPath;
  }

  @override
  Future<void> deleteAudioFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<int> getAudioFileSize(String path) async {
    return File(path).length();
  }

  @override
  Future<List<int>> readAudioFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return bytes.toList();
  }

  @override
  Stream<List<int>>? getAudioStream() {
    return null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
