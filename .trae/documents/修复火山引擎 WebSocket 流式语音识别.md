# 语音识别 (ASR) 修复方案

经过分析，当前代码实现与您提供的文档存在差异，且导致功能不可用的主要原因是 **接口端点 (Endpoint)** 和 **请求参数结构** 不匹配。

## 🔍 问题分析

1. **协议不匹配**：

   * **您的代码**：实现了 **WebSocket 流式识别** (`DoubaoASRClient`)，这是实时语音转写的最佳实践。

   * **您提供的文档**：是 **录音文件识别 (HTTP)**，适用于上传录音文件后异步获取结果，**不适合** 当前的实时录音场景。
2. **代码实现问题**：

   * **Endpoint 错误**：当前使用的是 `wss://.../api/v3/sauc/bigmodel_async`，这可能是一个过时或错误的内部接口。

   * **Payload 结构错误**：当前发送的 JSON 参数结构不符合火山引擎标准流式 ASR (v2) 的规范。

## 🛠️ 修复计划

为了实现“调通语音识别能力”的目标，建议 **保留 WebSocket 流式方案** 并修复其实现，使其符合火山引擎标准协议。

### 1. 修改接口配置 (`AppConstants.dart`)

* 将 ASR Endpoint 修正为火山引擎标准流式接口：`wss://openspeech.bytedance.com/api/v2/asr`

### 2. 重构 `DoubaoASRClient.dart`

* **更新启动帧 (Full Client Request)**：

  * 将 JSON 结构调整为标准 v2 格式，包含 `app`, `user`, `audio`, `request` 四个核心对象。

  * 确保 `appid`, `token` (Access Key), `cluster` (原 resource\_id) 正确映射。

* **优化参数配置**：

  * 设置 `format: raw` (PCM), `rate: 16000`, `bits: 16`, `channel: 1`。

  * 启用 `enable_punc` (标点) 和 `enable_ddc` (顺滑)。

### 3. 验证与测试

* 使用 `flutter run` 运行应用。

* 进行录音测试，验证是否能收到 `ASRResponse` 并正确解析文本。

***

### ❓ 确认事项

* 请确认您在 `.env` 文件中配置的 `DOUBAO_ASR_RESOURCE_ID` 是类似 `volc.bigasr.sauc` 的集群 ID (Cluster ID)。如果不是，请在火山引擎控制台确认您的流式语音识别服务的 Cluster ID。

* 如果您**坚持**要改为“录音文件识别 (HTTP)”方案（即录音完成后再上传识别），请告知，我将重写整个 ASR 模块（但这会增加等待时间，体验不如流式）。

**默认我将执行上述 WebSocket 修复方案。  **

你说得对，我不应该使用录音的方式来完成，以下是流失语音识别的API文档，你可以继续阅读学习下，<https://www.volcengine.com/docs/6561/1354869?lang=zh>

我们还是应该基于流式，**WebSocket的技术，来实现语音识别功能，先不着急编码，先把API文档搞清楚，我们再动手**
