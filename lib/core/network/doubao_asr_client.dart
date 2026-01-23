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
  bool _sessionReady = false;
  Completer<void>? _handshakeCompleter;

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
      // 确保参数没有多余空格
      appKey = appKey.trim();
      accessKey = accessKey.trim();
      resourceId = resourceId.trim();

      final baseUri = Uri.parse(AppConstants.doubaoAsrEndpoint);
      final uri = baseUri.replace(queryParameters: {
        'appkey': appKey,
        'token': accessKey,
        'resource_id': resourceId,
      });

      print('ASRClient: Connecting to $uri');
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['websocket'],
      );
      _sessionReady = false;
      _handshakeCompleter = Completer<void>();
      
      // 监听消息
      _channel!.stream.listen(
        (message) {
          print('ASRClient: Received message');
          _handleMessage(message);
        },
        onError: (error) {
          print('ASRClient: WebSocket Error: $error');
          _responseController.addError(error);
        },
        onDone: () {
          print('ASRClient: WebSocket connection closed');
          _cleanup();
        },
      );

      print('ASRClient: Sending start message...');
      // 发送初始配置消息 (Full Client Request)
      await _sendStartMessage(
        appKey: appKey,
        accessKey: accessKey,
        resourceId: resourceId,
      );
      print('ASRClient: Start message sent');
    } catch (e) {
      print('ASRClient: Connection failed: $e');
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
        'format': 'aac', // 改为 aac，因为录音文件是 m4a/aac 格式
        'codec': 'aac', 
        'rate': 16000,
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
    
    print('ASRClient: Start payload: ${json.encode(payload)}');

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

      final payloadSize = (message[4] << 24) |
          (message[5] << 16) |
          (message[6] << 8) |
          message[7];
      
      print('ASRClient: Payload size: $payloadSize');

      // 如果 payloadSize 仍然异常大（比如 > 10MB），可能是因为我们对协议理解有误
      // 或者服务器返回的不是标准协议头
      // 让我们观察一下 hexPreview: 11 f0 10 00 02 ae a5 40 00 00 00 c9 7b 22 ...
      // Byte 0: 11 -> Ver=1, HdrSz=1
      // Byte 1: f0 -> MsgType=15(0xF=ServerError?), Flags=0
      // Byte 2: 10 -> Ser=1(JSON), Comp=0(None)
      // Byte 3: 00 -> Reserved
      // Byte 4-7: 02 ae a5 40 -> 0x02aea540 = 45000000 ??? 这里的 Size 确实很大！
      // 
      // 等等，如果 Byte 4-7 是 02 ae a5 40，那确实是 45000000。
      // 但是消息总长度只有 213 字节。
      // 这意味着：
      // 1. 服务器返回的 Payload Size 字段含义可能不是“剩余字节数”？
      // 2. 或者这个消息是 GZIP 压缩后的？但是 Compression=0。
      // 3. 或者... Byte 4-7 实际上是 Sequence Number？
      //
      // 让我们再看一眼文档或参考实现。通常 Payload Size 是紧跟 Header 的。
      // 如果 02 ae a5 40 不是 Size，那真正的 Size 在哪里？
      //
      // 让我们尝试另一种假设：
      // 也许 Header 是 8 字节？
      // 如果 HeaderSize=1 代表 4 字节，那么前 4 字节是 Header。
      // 紧接着 4 字节是 Payload Size。
      //
      // 让我们看看后面的字节：00 00 00 c9
      // 0x000000c9 = 201
      // 消息总长 213。Header(4) + SizeField(4) + Payload(201) = 209。
      // 209 + 4 (Extra?) = 213?
      // 或者 Header(4) + Sequence(4) + Size(4) + Payload?
      //
      // 让我们看看 Hex:
      // 11 f0 10 00 (Header, 4 bytes)
      // 02 ae a5 40 (Unknown, 4 bytes, maybe Sequence?)
      // 00 00 00 c9 (Size? 0xc9 = 201)
      // 7b 22 72 65 (Payload start: {"re...)
      //
      // 验证：213 - 12 = 201。
      // 所以协议格式应该是：
      // [Header: 4 bytes]
      // [Sequence Number: 4 bytes] (02 ae a5 40)
      // [Payload Size: 4 bytes] (00 00 00 c9 = 201)
      // [Payload: 201 bytes]
      //
      // 修正解析逻辑：跳过 Sequence Number (4 bytes)

      if (message.length < 12) {
         print('ASRClient: Message too short for sequence and size');
         return;
      }

      // 跳过 4 字节 Sequence Number (Bytes 4-7)
      // 读取 Bytes 8-11 作为 Payload Size
      final realPayloadSize = (message[8] << 24) |
          (message[9] << 16) |
          (message[10] << 8) |
          message[11];
      
      print('ASRClient: Real Payload size: $realPayloadSize');

      if (message.length < 12 + realPayloadSize) {
        print('ASRClient: Incomplete message. Expected ${12 + realPayloadSize}, got ${message.length}');
        return; 
      }

      final payload = message.sublist(12, 12 + realPayloadSize);
      
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
    await _channel?.sink.close();
    _cleanup();
  }

  /// 清理资源
  void _cleanup() {
    _channel = null;
    _sessionReady = false;
    _handshakeCompleter = null;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
