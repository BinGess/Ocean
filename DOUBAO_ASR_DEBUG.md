# 豆包 ASR WebSocket 调试指南

## 当前错误分析

### 错误信息
```
WebSocketException: Connection to 'https://openspeech.bytedance.com:0/...' was not upgraded to websocket, HTTP status code: 400
```

### 可能的原因

#### 1. **认证方式问题** ⚠️
豆包 ASR API 可能需要使用**签名认证**而不是简单的 URL 参数认证。

**需要检查的内容：**
- 是否需要生成请求签名（HMAC-SHA256）
- 是否需要在 HTTP Header 中添加认证信息
- Token 是否需要特殊格式化

#### 2. **API 密钥格式问题**
从日志看到：
- `appkey`: `volcengine_standalone_project_2101749512_platform_ArkAPI`
- `token`: `Rs4surrw...` (Access Key)
- `resource_id`: `volc.seedasr.sauc.duration`

**验证步骤：**
1. 检查 appkey 格式是否正确
2. 确认 token 就是 Access Key（不是 Secret Key）
3. 验证 resource_id 是否与您的账号匹配

#### 3. **WebSocket 协议升级失败**
HTTP 400 表示服务器拒绝了 WebSocket 升级请求。

**可能原因：**
- URL 参数格式不正确
- 缺少必需的 HTTP Header
- 认证信息不完整

## 解决方案

### 方案 1：检查豆包 ASR 官方文档

访问火山引擎官方文档确认：
1. 正确的认证方式（URL 参数 vs. Header 认证）
2. 是否需要签名
3. WebSocket 连接的完整示例

**文档链接：**
- 火山引擎语音识别文档：https://www.volcengine.com/docs/6561/79820
- ASR WebSocket API：https://www.volcengine.com/docs/6561/80816

### 方案 2：验证 API 密钥

**检查清单：**
- [ ] appkey 是从火山引擎控制台获取的正确值
- [ ] Access Key（token）未过期且有效
- [ ] Resource ID 与您的服务配置匹配
- [ ] API 账号有足够的权限和配额

### 方案 3：使用 REST API 作为备选

如果 WebSocket 认证复杂，可以先使用 HTTP REST API 进行测试：

```dart
// 示例：使用 REST API 上传音频文件
Future<String> transcribeWithRestAPI(Uint8List audioData) async {
  final dio = Dio();

  final formData = FormData.fromMap({
    'audio': MultipartFile.fromBytes(audioData, filename: 'audio.pcm'),
    'format': 'pcm',
    'rate': 16000,
    // ... 其他参数
  });

  final response = await dio.post(
    'https://openspeech.bytedance.com/api/v1/asr',
    data: formData,
    options: Options(
      headers: {
        'Authorization': 'Bearer $accessToken',
        // 或者使用其他认证方式
      },
    ),
  );

  return response.data['result']['text'];
}
```

### 方案 4：添加签名认证

豆包 API 可能需要计算请求签名：

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateSignature({
  required String accessKeyId,
  required String secretAccessKey,
  required String service,
  required String region,
  required DateTime timestamp,
}) {
  // 1. 构建签名字符串
  final dateStamp = timestamp.toIso8601String().split('T')[0];
  final credentialScope = '$dateStamp/$region/$service/request';

  // 2. 计算 HMAC-SHA256
  final key = utf8.encode(secretAccessKey);
  final message = utf8.encode(credentialScope);
  final hmac = Hmac(sha256, key);
  final signature = hmac.convert(message);

  return signature.toString();
}

// 在连接时使用签名
Future<void> connectWithSignature() async {
  final timestamp = DateTime.now().toUtc();
  final signature = generateSignature(
    accessKeyId: appKey,
    secretAccessKey: accessKey,
    service: 'asr',
    region: 'cn-north-1',
    timestamp: timestamp,
  );

  final uri = baseUri.replace(
    queryParameters: {
      'X-Date': timestamp.toIso8601String(),
      'X-Credential': '$appKey/$credentialScope',
      'X-Signature': signature,
    },
  );

  _channel = WebSocketChannel.connect(uri);
}
```

## 下一步调试建议

### 1. 启用详细日志
修改 `DoubaoASRClient` 添加详细的连接日志：

```dart
Future<void> connect(...) async {
  try {
    final uri = baseUri.replace(queryParameters: {...});

    print('🔗 连接 WebSocket:');
    print('   URL: ${uri.toString()}');
    print('   Scheme: ${uri.scheme}');
    print('   Host: ${uri.host}');
    print('   Port: ${uri.port}');
    print('   Path: ${uri.path}');
    print('   Query: ${uri.query}');

    _channel = WebSocketChannel.connect(uri);
    // ...
  }
}
```

### 2. 使用 curl 测试
尝试用 curl 命令测试连接：

```bash
# 测试 WebSocket 升级
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async?appkey=YOUR_APPKEY&token=YOUR_TOKEN&resource_id=YOUR_RESOURCE_ID"
```

### 3. 检查网络和防火墙
- 确保设备可以访问 `openspeech.bytedance.com`
- 检查是否有代理或 VPN 影响 WebSocket 连接
- 在模拟器上测试可能有网络限制

## 临时解决方案

如果 WebSocket 问题短期内无法解决，可以：

1. **使用本地测试数据**：模拟 ASR 响应进行 UI 测试
2. **使用其他 ASR 服务**：如阿里云、腾讯云作为备选
3. **等待火山引擎技术支持**：联系官方获取正确的集成方式

## 相关文件

- WebSocket 客户端：`lib/core/network/doubao_asr_client.dart`
- API 配置：`lib/core/constants/app_constants.dart`
- 环境变量：`.env`
- API 测试页面：`lib/presentation/screens/debug/api_test_screen.dart`

## 更新记录

- 2026-01-23: 修复 WebSocket URL 构建问题，移除重复连接
- 2026-01-23: 添加此调试文档
