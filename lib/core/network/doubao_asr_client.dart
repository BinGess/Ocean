/// 豆包 ASR (语音识别) 客户端
/// 实现 WebSocket 二进制协议 (v3 API)
/// 官方文档: https://www.volcengine.com/docs/6561/1354869
library doubao_asr_client;

/// 协议格式：
/// - Header (4 bytes): 协议版本 | Header 大小 | 消息类型 | 消息标志 | 序列化方法 | 压缩方法
/// - Payload Size (4 bytes): 负载大小（大端序）
/// - Payload: JSON 或 音频数据

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
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
    // 判断成功：有 result 字段，或者 code 为 1000/0
    // 注意：v3 协议的 full result 响应可能没有 code 字段
    final hasResult = json.containsKey('result');
    final code = json['code'];
    final hasSuccessCode = code == 1000 || code == 0;
    final hasError = json.containsKey('error');
    
    // 解析 text
    // 结构通常是: {"result": {"text": "...", "utterances": [...]}}
    final result = json['result'];
    final text = result is Map ? result['text'] : null;

    // 解析 isFinal
    // v3 协议中，full 模式下，通常通过 utterances 中的 definite 字段判断
    // 或者如果没有 code 错误且有 result，我们可以认为是有效的中间或最终结果
    // 真正的 final 通常由业务逻辑（如 definite=true 或 connection closed）决定
    // 这里我们尝试从 result 中获取更多信息
    bool isFinal = json['is_final'] ?? false;
    
    if (!isFinal && result is Map && result['utterances'] is List) {
       final utterances = result['utterances'] as List;
       if (utterances.isNotEmpty) {
         final lastUtterance = utterances.last;
         if (lastUtterance is Map) {
           // definite=true 表示这句话已经确定
           if (lastUtterance['definite'] == true) {
             // 注意：这只是这句话 final，不是整个会话 final。
             // 但对于短语音识别，通常这句话就是全部。
             // 暂时将 definite=true 视为 isFinal update
             isFinal = true;
           }
         }
       }
    }

    return ASRResponse(
      success: (hasResult || hasSuccessCode) && !hasError,
      text: text,
      isFinal: isFinal,
      error: json['error'] ?? json['message'],
      rawData: json,
    );
  }
}

/// 豆包 ASR 客户端
class DoubaoASRClient {
  WebSocketChannel? _channel;
  final StreamController<ASRResponse> _responseController =
      StreamController<ASRResponse>.broadcast();
  bool _sessionReady = false;
  Completer<void>? _handshakeCompleter;

  /// 主动关闭标志。
  /// finishAudio() 发出最后一帧后服务端预期会关闭连接；
  /// disconnect() 也会主动关闭。两处均设 true，告知 onDone 回调
  /// "这是预期关闭，无需向 _responseController 推送 SocketException"。
  /// disconnect() 结束后重置为 false，以便下次连接的意外断开仍能被侦测。
  bool _expectingClose = false;

  /// 响应流
  Stream<ASRResponse> get responses => _responseController.stream;

  /// 是否已连接
  bool get isConnected => _channel != null;

  /// 连接到 WebSocket
  ///
  /// [appKey] API App Key (X-Api-App-Key)
  /// [accessKey] API Access Key (X-Api-Access-Key)
  /// [resourceId] 资源 ID (X-Api-Resource-Id)
  Future<void> connect({
    required String appKey,
    required String accessKey,
    required String resourceId,
  }) async {
    if (_channel != null) {
      throw Exception('Already connected. Disconnect first.');
    }

    try {
      // 确保参数没有多余空格
      appKey = appKey.trim();
      accessKey = accessKey.trim();
      resourceId = resourceId.trim();

      final wsUri = Uri.parse(AppConstants.doubaoAsrEndpoint);
      final connectId = const Uuid().v4();

      print('🔌 ASRClient: 连接 WebSocket...');
      print('   WS-URL: ${wsUri.toString()}');
      print('   Scheme: ${wsUri.scheme}');
      print('   Host: ${wsUri.host}');
      print('   Path: ${wsUri.path}');
      print('   App-Key: ${appKey.substring(0, 8)}...');
      print('   Access-Key: ${accessKey.substring(0, 8)}...');
      print('   Resource-Id: $resourceId');
      print('   Connect-Id: $connectId');

      // 将 wss:// 转换为 https:// 用于 HttpClient
      // WebSocket over TLS 使用 HTTPS 进行初始握手
      final httpUri = wsUri.replace(scheme: wsUri.scheme == 'wss' ? 'https' : 'http');

      print('   HTTP-URL (for handshake): ${httpUri.toString()}');

      // 使用 HttpClient 建立 WebSocket 连接，确保 headers 正确传递
      final httpClient = HttpClient();

      // 创建 WebSocket 请求
      final request = await httpClient.getUrl(httpUri);

      // 设置必需的 WebSocket headers
      request.headers
        ..set('Connection', 'Upgrade')
        ..set('Upgrade', 'websocket')
        ..set('Sec-WebSocket-Version', '13')
        ..set('Sec-WebSocket-Key', _generateWebSocketKey())
        // 添加豆包 API 认证 headers
        ..set('X-Api-App-Key', appKey)
        ..set('X-Api-Access-Key', accessKey)
        ..set('X-Api-Resource-Id', resourceId)
        ..set('X-Api-Connect-Id', connectId);

      print('📤 发送 WebSocket 握手请求...');
      print('   Headers: ${request.headers.toString()}');

      final response = await request.close();

      print('📥 收到响应:');
      print('   Status: ${response.statusCode}');
      print('   Headers: ${response.headers.toString()}');

      if (response.statusCode != 101) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception(
          'WebSocket 握手失败: HTTP ${response.statusCode}\n'
          'Response: $body',
        );
      }

      // 升级到 WebSocket
      final socket = await response.detachSocket();
      final webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: false);

      print('✅ ASRClient: WebSocket 握手成功!');
      print('   X-Tt-Logid: ${response.headers.value('X-Tt-Logid')}');

      // 包装为 WebSocketChannel
      _channel = IOWebSocketChannel(webSocket);
      _sessionReady = false;
      _handshakeCompleter = Completer<void>();
      _expectingClose = false; // 新连接重置标志

      // 监听消息
      _channel!.stream.listen(
        (message) {
          print('ASRClient: Received message');
          _handleMessage(message);
        },
        onError: (error) {
          print('❌ ASRClient: WebSocket Error: $error');
          if (!_responseController.isClosed) {
            _responseController.addError(error);
          }
        },
        onDone: () {
          print('🔌 ASRClient: WebSocket connection closed');
          // _expectingClose=true：主动断开（finishAudio 后服务端关闭，或 disconnect()）
          //   → 静默处理，不推送错误（BLoC 已通过 _onFinalizeStreaming 管理状态）
          // _expectingClose=false：意外断开（网络中断等）
          //   → 推送 SocketException，让 BLoC 的 _onStreamError 感知并更新 UI
          if (!_expectingClose && !_responseController.isClosed) {
            _responseController.addError(
              const SocketException('WebSocket connection closed by server'),
            );
          }
          _cleanup();
        },
      );

      print('📤 ASRClient: Sending start message...');
      // 发送初始配置消息 (Full Client Request)
      await _sendStartMessage();
      print('✅ ASRClient: Start message sent');

      // 根据 API 文档，发送 Full Client Request 后立即可以开始发送音频数据
      // 不需要等待服务端确认
      _sessionReady = true;
      if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
        _handshakeCompleter!.complete();
      }
    } catch (e) {
      print('❌ ASRClient: Connection failed: $e');
      _cleanup();
      rethrow;
    }
  }

  /// 生成 WebSocket Sec-WebSocket-Key
  String _generateWebSocketKey() {
    final random = List<int>.generate(16, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64.encode(random);
  }

  /// 发送启动消息 (Full Client Request)
  /// 格式按照 v3 API 官方文档要求
  Future<void> _sendStartMessage() async {
    final payload = {
      'user': {
        'uid': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      'audio': {
        'format': 'pcm', // PCM 格式（裸PCM数据，无容器头）
        'codec': 'raw', // raw codec
        'rate': AppConstants.audioSampleRate, // 16000
        'bits': AppConstants.audioBitRate, // 16
        'channel': AppConstants.audioChannels, // 1
      },
      'request': {
        'model_name': 'bigmodel', // 必填字段
        'enable_itn': true, // 启用文本规范化
        'enable_punc': true, // 启用标点
        'enable_ddc': false, // 启用语义顺滑
        'show_utterances': true, // 输出分句信息
        'result_type': 'full', // full(全量) / single(增量)
      },
    };

    print('📤 ASRClient: Start payload (v3 format):');
    print('   ${json.encode(payload)}');

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

    if (!_sessionReady && _handshakeCompleter != null) {
      await _handshakeCompleter!.future
          .timeout(const Duration(seconds: 10));
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

    if (!_sessionReady && _handshakeCompleter != null) {
      await _handshakeCompleter!.future
          .timeout(const Duration(seconds: 10));
    }

    // 发出 isLast 后服务端会主动关闭连接，属于预期行为
    _expectingClose = true;

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
      print('ASRClient: Message is not Uint8List: ${message.runtimeType}');
      return;
    }
    
    print('ASRClient: Received bytes length: ${message.length}');
    // 打印前 16 个字节的 Hex，帮助调试
    final hexPreview = message.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('ASRClient: Hex Preview: $hexPreview');

    try {
      // 解析 header
      if (message.length < 4) { // Header 只有 4 字节
        print('ASRClient: Message too short for header');
        return; 
      }

      // 检查协议版本和 Header 大小
      final firstByte = message[0];
      final version = (firstByte >> 4) & 0x0F;
      final headerSz = firstByte & 0x0F;
      print('ASRClient: Version: $version, HeaderSize: $headerSz');

      // 关键修正：Header 大小单位是“4字节字”，所以 headerSz=1 代表 4 字节
      // 但是 Payload Size 不在 Header 内，而是紧跟在 Header 后面
      // Header 结构 (4 bytes):
      // Byte 0: [Version:4][HeaderSize:4]
      // Byte 1: [MessageType:4][Flags:4]
      // Byte 2: [Serialization:4][Compression:4]
      // Byte 3: [Reserved:8]
      //
      // Payload Size 结构 (4 bytes):
      // Byte 4-7: [Size:32] (Big Endian)

      if (message.length < 8) {
         print('ASRClient: Message too short for payload size');
         return;
      }

      // 尝试读取 Bytes 4-7 作为 Payload Size（假设没有 Sequence Number）
      final payloadSizeNoSeq = (message[4] << 24) |
          (message[5] << 16) |
          (message[6] << 8) |
          message[7];

      print('ASRClient: Payload size (no seq): $payloadSizeNoSeq');

      // 检查协议格式：某些消息有 Sequence Number (4 bytes)，某些没有
      // 判断方法：验证 message.length 是否匹配两种格式之一
      // 格式1 (8字节header): Header(4) + PayloadSize(4) + Payload
      // 格式2 (12字节header): Header(4) + Sequence(4) + PayloadSize(4) + Payload

      final hasSequenceNumber = (message.length != 8 + payloadSizeNoSeq) && message.length >= 12;

      int headerLength;
      int payloadSize;

      if (hasSequenceNumber && message.length >= 12) {
        // 格式2: 有 Sequence Number
        final sequenceNumber = (message[4] << 24) |
            (message[5] << 16) |
            (message[6] << 8) |
            message[7];

        payloadSize = (message[8] << 24) |
            (message[9] << 16) |
            (message[10] << 8) |
            message[11];

        headerLength = 12;
        print('ASRClient: Format with Sequence Number: $sequenceNumber, Payload size: $payloadSize');
      } else {
        // 格式1: 没有 Sequence Number
        payloadSize = payloadSizeNoSeq;
        headerLength = 8;
        print('ASRClient: Format without Sequence Number, Payload size: $payloadSize');
      }

      if (message.length < headerLength + payloadSize) {
        print('ASRClient: Incomplete message. Expected ${headerLength + payloadSize}, got ${message.length}');
        return;
      }

      final payload = message.sublist(headerLength, headerLength + payloadSize);
      
      // 尝试打印 Payload 内容（如果是文本）
      try {
         // 检查 Serialization Method
         final serialization = (message[2] >> 4) & 0x0F;
         final compression = message[2] & 0x0F;
         print('ASRClient: Serialization: $serialization, Compression: $compression');

         if (compression == CompressionMethod.gzip.value) {
            print('ASRClient: GZIP compression not supported yet');
            // TODO: Handle GZIP
            return;
         }

         final jsonStr = utf8.decode(payload);
         print('ASRClient: Response JSON: $jsonStr');
         final jsonData = json.decode(jsonStr) as Map<String, dynamic>;

         final code = jsonData['code'];
         final messageText = jsonData['message']?.toString();
         if (!_sessionReady) {
           if (code == 0 || code == 1000) {
             _sessionReady = true;
             if (_handshakeCompleter != null &&
                 !_handshakeCompleter!.isCompleted) {
               _handshakeCompleter!.complete();
             }
           } else if (messageText != null &&
               messageText.startsWith('setup session')) {
             if (_handshakeCompleter != null &&
                 !_handshakeCompleter!.isCompleted) {
               _handshakeCompleter!
                   .completeError(Exception(messageText));
             }
           }
         }

         // 构建响应
         final response = ASRResponse.fromJson(jsonData);
         _responseController.add(response);
      } catch (e) {
         print('ASRClient: Failed to decode payload as JSON: $e');
      }

    } catch (e) {
      print('ASRClient: Error handling message: $e');
      _responseController.addError(e);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _expectingClose = true; // 主动断开，onDone 不推送错误
    await _channel?.sink.close();
    _cleanup();
    _expectingClose = false; // 重置，下次连接的意外断开仍能被感知
  }

  /// 清理资源
  void _cleanup() {
    _channel = null;
    _sessionReady = false;
    _handshakeCompleter = null;
    // 注意：_expectingClose 由 disconnect() 管理，此处不重置
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
