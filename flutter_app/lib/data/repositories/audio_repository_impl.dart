/// 音频仓储实现
/// 使用 record 包进行音频录制

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/audio_repository.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _recordingStartTime;

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
  }

  @override
  double getCurrentDuration() {
    if (_recordingStartTime == null) {
      return 0.0;
    }
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
