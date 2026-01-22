/// 豆包 ASR (语音识别) 客户端
/// 实现 WebSocket 二进制协议
///
/// 协议格式：
/// - Header (4 bytes): 协议版本 | 消息类型 | 序列化方法 | 压缩方法
/// - Payload Size (4 bytes): 负载大小（大端序）
/// - Payload: JSON 或 音频数据

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';

/// 协议版本
const int protocolVersion = 0b0001;

/// Header 大小（字节）
const int headerSize = 0b0001;

/// 消息类型
enum MessageType {
  client(0b0001), // 客户端消息（JSON）
  audio(0b1011), // 音频数据
  server(0b1111); // 服务器响应（JSON）

  final int value;
  const MessageType(this.value);
}

/// 消息标志
enum MessageFlags {
  none(0b0000), // 无标志
  noSerial(0b0001), // 无序列号
  hasSerial(0b0011), // 有序列号
  ack(0b1001); // 确认消息

  final int value;
  const MessageFlags(this.value);
}

/// 序列化方法
enum SerializationMethod {
  json(0b0001), // JSON
  protobuf(0b0010), // Protobuf（暂不支持）
  thrift(0b0011); // Thrift（暂不支持）

  final int value;
  const SerializationMethod(this.value);
}

/// 压缩方法
enum CompressionMethod {
  none(0b0000), // 无压缩
  gzip(0b0001), // GZIP
  lz4(0b0010); // LZ4（暂不支持）

  final int value;
  const CompressionMethod(this.value);
}

/// WebSocket 消息响应
class ASRResponse {
  final bool success;
  final String? text;
  final bool isFinal;
  final String? error;
  final Map<String, dynamic>? rawData;

  ASRResponse({
    required this.success,
    this.text,
    this.isFinal = false,
    this.error,
    this.rawData,
  });

  factory ASRResponse.fromJson(Map<String, dynamic> json) {
    return ASRResponse(
      success: json['code'] == 1000 || json['code'] == 0,
      text: json['result']?['text'],
      isFinal: json['is_final'] ?? false,
      error: json['message'],
      rawData: json,
    );
  }
}

/// 豆包 ASR 客户端
class DoubaoASRClient {
  WebSocketChannel? _channel;
  final StreamController<ASRResponse> _responseController =
      StreamController<ASRResponse>.broadcast();

  /// 响应流
  Stream<ASRResponse> get responses => _responseController.stream;

  /// 是否已连接
  bool get isConnected => _channel != null;

  /// 连接到 WebSocket
  ///
  /// [appKey] API App Key
  /// [accessKey] API Access Key
  /// [resourceId] 资源 ID
  Future<void> connect({
    required String appKey,
    required String accessKey,
    required String resourceId,
  }) async {
    if (_channel != null) {
      throw Exception('Already connected. Disconnect first.');
    }

    try {
      // 构建 WebSocket URI
      final uri = Uri.parse(AppConstants.doubaoAsrEndpoint);

      // 创建 WebSocket 连接（Dart 支持自定义 headers！）
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['websocket'],
      );

      // 注意：web_socket_channel 在某些平台上可能不支持自定义 headers
      // 对于生产环境，需要使用 dart:io WebSocket 或其他支持自定义 headers 的库
      // 这里先使用 URL 参数作为替代方案
      final uriWithParams = Uri.parse(
        '${AppConstants.doubaoAsrEndpoint}?'
        'appkey=$appKey&'
        'token=$accessKey&'
        'resource_id=$resourceId',
      );

      _channel = WebSocketChannel.connect(uriWithParams);

      // 监听消息
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _responseController.addError(error);
        },
        onDone: () {
          _cleanup();
        },
      );

      // 发送初始配置消息
      await _sendStartMessage(resourceId: resourceId);
    } catch (e) {
      _cleanup();
      rethrow;
    }
  }

  /// 发送启动消息
  Future<void> _sendStartMessage({required String resourceId}) async {
    final payload = {
      'version': '0.1.0',
      'header': {
        'app_id': 'mindflow',
        'uid': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      'payload': {
        'task': 'asr',
        'resource_id': resourceId,
        'audio': {
          'format': 'pcm',
          'sample_rate': AppConstants.audioSampleRate,
          'channel': 1,
          'bits': 16,
        },
        'request': {
          'nbest': 1,
          'enable_vad': true,
          'enable_punctuation': true,
          'enable_inverse_text_normalization': true,
        },
      },
    };

    await _sendMessage(
      messageType: MessageType.client,
      flags: MessageFlags.none,
      serialization: SerializationMethod.json,
      compression: CompressionMethod.none,
      payload: utf8.encode(json.encode(payload)),
    );
  }

  /// 发送音频数据
  Future<void> sendAudio(Uint8List audioData) async {
    if (_channel == null) {
      throw Exception('Not connected. Call connect() first.');
    }

    await _sendMessage(
      messageType: MessageType.audio,
      flags: MessageFlags.none,
      serialization: SerializationMethod.json,
      compression: CompressionMethod.none,
      payload: audioData,
    );
  }

  /// 发送音频结束标记
  Future<void> finishAudio() async {
    if (_channel == null) {
      throw Exception('Not connected. Call connect() first.');
    }

    // 发送空音频包表示结束
    await _sendMessage(
      messageType: MessageType.audio,
      flags: MessageFlags.none,
      serialization: SerializationMethod.json,
      compression: CompressionMethod.none,
      payload: Uint8List(0),
    );
  }

  /// 构建并发送消息
  Future<void> _sendMessage({
    required MessageType messageType,
    required MessageFlags flags,
    required SerializationMethod serialization,
    required CompressionMethod compression,
    required Uint8List payload,
  }) async {
    final message = _buildMessage(
      messageType: messageType,
      flags: flags,
      serialization: serialization,
      compression: compression,
      payload: payload,
    );

    _channel!.sink.add(message);
  }

  /// 构建二进制消息
  ///
  /// 消息格式：
  /// - Byte 0: [4 bits: 协议版本] [4 bits: Header 大小]
  /// - Byte 1: [4 bits: 消息类型] [4 bits: 消息标志]
  /// - Byte 2: [4 bits: 序列化方法] [4 bits: 压缩方法]
  /// - Byte 3: 保留字节
  /// - Bytes 4-7: Payload 大小（大端序）
  /// - Bytes 8+: Payload 数据
  Uint8List _buildMessage({
    required MessageType messageType,
    required MessageFlags flags,
    required SerializationMethod serialization,
    required CompressionMethod compression,
    required Uint8List payload,
  }) {
    // Header (4 bytes)
    final header = Uint8List(4);
    header[0] = (protocolVersion << 4) | headerSize;
    header[1] = (messageType.value << 4) | flags.value;
    header[2] = (serialization.value << 4) | compression.value;
    header[3] = 0x00; // Reserved

    // Payload size (4 bytes, big-endian)
    final payloadSize = Uint8List(4);
    final size = payload.length;
    payloadSize[0] = (size >> 24) & 0xFF;
    payloadSize[1] = (size >> 16) & 0xFF;
    payloadSize[2] = (size >> 8) & 0xFF;
    payloadSize[3] = size & 0xFF;

    // 组合消息
    final message = Uint8List(header.length + payloadSize.length + payload.length);
    message.setRange(0, header.length, header);
    message.setRange(header.length, header.length + payloadSize.length, payloadSize);
    message.setRange(
      header.length + payloadSize.length,
      message.length,
      payload,
    );

    return message;
  }

  /// 处理接收到的消息
  void _handleMessage(dynamic message) {
    if (message is! Uint8List) {
      return;
    }

    try {
      // 解析 header
      if (message.length < 8) {
        return; // 消息太短，忽略
      }

      // 提取 payload size（大端序）
      final payloadSize = (message[4] << 24) |
          (message[5] << 16) |
          (message[6] << 8) |
          message[7];

      // 提取 payload
      if (message.length < 8 + payloadSize) {
        return; // 消息不完整
      }

      final payload = message.sublist(8, 8 + payloadSize);

      // 解析 JSON
      final jsonStr = utf8.decode(payload);
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;

      // 构建响应
      final response = ASRResponse.fromJson(jsonData);
      _responseController.add(response);
    } catch (e) {
      _responseController.addError(e);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _cleanup();
  }

  /// 清理资源
  void _cleanup() {
    _channel = null;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
