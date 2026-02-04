/// 音频仓储实现
/// 使用 record 包进行音频录制

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/audio_repository.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _recordingStartTime;

  // 流式录音相关
  StreamController<List<int>>? _audioStreamController;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _isStreamMode = false;
  String? _streamAudioPath; // 流式模式下的音频文件路径（用于备份）
  IOSink? _audioFileSink; // 用于将流数据写入文件

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
      final path = '${directory.path}/audio_$timestamp.wav';

      // 配置录音参数（匹配豆包 ASR API 要求：PCM 16kHz 16bit mono）
      const config = RecordConfig(
        encoder: AudioEncoder.wav, // WAV 格式（PCM 编码）
        sampleRate: 16000, // 16kHz
        bitRate: 256000, // WAV: 16000 * 16 * 1 = 256kbps
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

  /// 开始流式录音（用于实时转写）
  /// 返回值：是否成功开始录音
  Future<bool> startStreamingRecording() async {
    try {
      // 检查权限
      if (!await _recorder.hasPermission()) {
        debugPrint('AudioRepository: 没有录音权限');
        return false;
      }

      // 标记为流式模式
      _isStreamMode = true;

      // 创建广播流控制器
      _audioStreamController = StreamController<List<int>>.broadcast();

      // 生成录音文件路径（用于备份）
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _streamAudioPath = '${directory.path}/audio_stream_$timestamp.wav';

      // 创建文件写入流
      final file = File(_streamAudioPath!);
      _audioFileSink = file.openWrite();

      // 配置录音参数（PCM 16kHz 16bit mono）
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // PCM格式，用于流式传输
        sampleRate: 16000, // 16kHz
        bitRate: 256000,
        numChannels: 1, // 单声道
      );

      debugPrint('AudioRepository: 开始流式录音');

      // 开始流式录音
      final stream = await _recorder.startStream(config);
      _recordingStartTime = DateTime.now();

      // 监听音频流并转发
      _audioStreamSubscription = stream.listen(
        (audioChunk) {
          // 转发音频数据到流控制器
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
            _audioStreamController!.add(audioChunk);
          }
        },
        onError: (error) {
          debugPrint('AudioRepository: 音频流错误: $error');
          _audioStreamController?.addError(error);
        },
        onDone: () {
          debugPrint('AudioRepository: 音频流结束');
          _audioStreamController?.close();
        },
      );

      return true;
    } catch (e) {
      debugPrint('AudioRepository: 开始流式录音失败: $e');
      _isStreamMode = false;
      _audioStreamController?.close();
      _audioStreamController = null;
      return false;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      // 如果是流式模式，先清理流相关资源
      if (_isStreamMode) {
        debugPrint('AudioRepository: 停止流式录音');

        // 停止录音器
        // 注意：如果是 startStream 启动的，stop() 可能返回 null
        await _recorder.stop();

        // 关键修复：确保文件写入流被刷新并关闭
        if (_audioFileSink != null) {
          await _audioFileSink!.flush();
          await _audioFileSink!.close();
          _audioFileSink = null;
        }

        // 取消音频流订阅
        await _audioStreamSubscription?.cancel();
        _audioStreamSubscription = null;

        // 关闭流控制器
        await _audioStreamController?.close();
        _audioStreamController = null;

        _isStreamMode = false;
        _recordingStartTime = null;

        debugPrint('AudioRepository: 流式录音已停止，文件路径: $_streamAudioPath');
        return _streamAudioPath;
      }

      // 停止录音
      final path = await _recorder.stop();
      _recordingStartTime = null;

      debugPrint('AudioRepository: 录音已停止，文件路径: $path');
      return path ?? _streamAudioPath;
    } catch (e) {
      debugPrint('AudioRepository: 停止录音失败: $e');
      _recordingStartTime = null;
      _isStreamMode = false;
      // 即使出错也要尝试关闭 sink
      try {
        await _audioFileSink?.close();
        _audioFileSink = null;
      } catch (_) {}
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
    // 如果是流式模式，清理流资源
    if (_isStreamMode) {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      await _audioStreamController?.close();
      _audioStreamController = null;

      await _audioFileSink?.close();
      _audioFileSink = null;
      
      // 删除可能生成的临时文件
      if (_streamAudioPath != null) {
        deleteAudioFile(_streamAudioPath!);
      }

      _isStreamMode = false;
    }

    await _recorder.cancel();
    _recordingStartTime = null;
  }

  @override
  bool isRecording() {
    return _recordingStartTime != null;
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
    // 已经保存到持久存储，直接返回路径
    return tempPath;
  }

  @override
  Future<void> deleteAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略删除错误
    }
  }

  @override
  Future<int> getAudioFileSize(String path) async {
    try {
      final file = File(path);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<int>> readAudioFile(String path) async {
    try {
      final file = File(path);
      return await file.readAsBytes();
    } catch (e) {
      return [];
    }
  }

  @override
  Stream<List<int>>? getAudioStream() {
    // 返回广播流，允许多个监听者
    return _audioStreamController?.stream;
  }

  @override
  Future<void> warmUp() async {
    try {
      // 预热权限与目录访问，降低首次录音时的 IO 抖动
      await _recorder.hasPermission();
      await getApplicationDocumentsDirectory();
    } catch (_) {
      // 忽略预热失败
    }
  }

  Future<void> dispose() async {
    // 清理流资源
    await _audioStreamSubscription?.cancel();
    await _audioStreamController?.close();

    // 释放录音器资源
    await _recorder.dispose();
  }
}
