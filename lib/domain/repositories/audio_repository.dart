// 音频仓储接口（Repository Interface）
// 定义音频录制和处理相关的契约

abstract class AudioRepository {
  /// 开始录音
  /// 返回值：true 表示成功，false 表示失败
  Future<bool> startRecording();

  /// 开始流式录音（用于实时转写）
  /// 返回值：true 表示成功，false 表示失败
  Future<bool> startStreamingRecording();

  /// 停止录音
  /// 返回值：录音文件的本地路径
  Future<String?> stopRecording();

  /// 暂停录音
  Future<void> pauseRecording();

  /// 恢复录音
  Future<void> resumeRecording();

  /// 取消录音
  Future<void> cancelRecording();

  /// 检查是否正在录音
  bool isRecording();

  /// 获取当前录音时长（秒）
  double getCurrentDuration();

  /// 检查录音权限
  Future<bool> checkPermission();

  /// 请求录音权限
  Future<bool> requestPermission();

  /// 保存音频文件到持久存储
  /// [tempPath] 临时文件路径
  /// 返回值：持久化后的文件路径
  Future<String> saveAudioFile(String tempPath);

  /// 删除音频文件
  Future<void> deleteAudioFile(String path);

  /// 获取音频文件大小（字节）
  Future<int> getAudioFileSize(String path);

  /// 读取音频文件数据
  Future<List<int>> readAudioFile(String path);

  /// 获取音频流（用于实时转录）
  /// 返回值：音频数据流
  Stream<List<int>>? getAudioStream();
}
