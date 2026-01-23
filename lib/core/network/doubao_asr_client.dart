/// 豆包 ASR (语音识别) 客户端
/// 实现 WebSocket 二进制协议 (v2)
library doubao_asr_client;

/// 协议格式：
/// - Header (4 bytes): 协议版本 | Header 大小 | 消息类型 | 消息标志 | 序列化方法 | 压缩方法
/// - Payload Size (4 bytes): 负载大小（大端序）
/// - Payload: JSON 或 音频数据

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

/// 协议版本
const int protocolVersion = 0x01;

/// Header 大小（4字节字的数量，这里为1，即4字节）
const int headerSize = 0x01;

/// 消息类型 (v2 Protocol)
enum MessageType {
  fullClientRequest(0x01), // 包含请求参数的完整客户端请求 (JSON)
  audioOnlyRequest(0x02), // 仅包含音频数据的请求
  fullServerResponse(0x09), // 服务端响应 (JSON)
  serverError(0x0F); // 服务端错误

  final int value;
  const MessageType(this.value);
}

/// 消息标志 (v2 Protocol)
enum MessageFlags {
  none(0x00), // 普通消息
  isLast(0x02); // 最后一包音频

  final int value;
  const MessageFlags(this.value);
}

/// 序列化方法
enum SerializationMethod {
  none(0x00),
  json(0x01),
  gzip(0x01); // 注意：v2中 0x1 在 Serialization 是 JSON，在 Compression 是 Gzip

  final int value;
  const SerializationMethod(this.value);
}

/// 压缩方法
enum CompressionMethod {
  none(0x00),
  gzip(0x01);

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
      // 构建 WebSocket URI（使用 Uri.parse 然后添加查询参数）
      final baseUri = Uri.parse(AppConstants.doubaoAsrEndpoint);

      // 创建 WebSocket 连接（Dart 支持自定义 headers！）
      // 对于生产环境，使用标准 WebSocket 连接，无需 URL 参数鉴权（将在 Payload 中鉴权）
      _channel = WebSocketChannel.connect(
        baseUri,
        protocols: ['websocket'],
      );
      // 创建 WebSocket 连接（Dart 支持自定义 headers！）
      // 对于生产环境，使用标准 WebSocket 连接，无需 URL 参数鉴权（将在 Payload 中鉴权）
      _channel = WebSocketChannel.connect(
        baseUri,
        protocols: ['websocket'],
      );
      
      // 监听消息
      _channel!.stream.listen(
          _responseController.addError(error);
        },
        onDone: () {
          _cleanup();
        },
      );

      // 发送初始配置消息 (Full Client Request)
      await _sendStartMessage(
        appKey: appKey,
        accessKey: accessKey,
        resourceId: resourceId,
      );
    } catch (e) {
      _cleanup();
      rethrow;
    }
  }

  /// 发送启动消息 (Full Client Request)
  Future<void> _sendStartMessage({
    required String appKey,
    required String accessKey,
    required String resourceId,
  }) async {
    const uuid = Uuid();
    final reqid = uuid.v4();

    final payload = {
      'app': {
        'appid': appKey,
        'token': accessKey,
        'cluster': resourceId,
      },
      'user': {
        'uid': 'user_id', // 建议替换为实际用户 ID
      },
      'audio': {
        'format': 'raw', // PCM 对应 raw
        'codec': 'raw', // PCM 对应 raw
        'rate': AppConstants.audioSampleRate,
        'bits': 16,
        'channel': 1,
      },
      'request': {
        'reqid': reqid,
        'workflow': 'audio_in,resample,partition,vad,fe,decode,itn,nlu_punctuate',
        'show_utterances': true,
        'result_type': 'full',
        'sequence': 1,
      },
    };

    await _sendMessage(
      messageType: MessageType.fullClientRequest,
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
      messageType: MessageType.audioOnlyRequest,
      flags: MessageFlags.none,
      serialization: SerializationMethod.none,
      compression: CompressionMethod.none,
      payload: audioData,
    );
  }

  /// 发送音频结束标记
  Future<void> finishAudio() async {
    if (_channel == null) {
      throw Exception('Not connected. Call connect() first.');
    }

    // 发送空音频包表示结束，并设置 isLast 标志
    await _sendMessage(
      messageType: MessageType.audioOnlyRequest,
      flags: MessageFlags.isLast,
      serialization: SerializationMethod.none,
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
