---
name: agent-request-result-parser
description: 智能体请求与结果解析复用流程。用于实现或重构“调用智能体或LLM API、接收普通或SSE流式响应、提取答案与JSON、进行容错修复与字段归一化、映射为强类型领域对象、处理重试和降级回退”的场景，尤其适用于响应格式不稳定、字段命名不统一、需要高鲁棒性解析的项目。
---
# agent-request-result-parser

将“请求智能体 + 解析结果”沉淀为可复用工程流程。优先保证可恢复性和可观测性，再追求最少代码量。

## 快速目标

在任意项目中实现以下能力：

1. 构造稳定的智能体请求（普通HTTP或SSE）。
2. 从混杂响应中提取有效答案文本。
3. 从纯文本/Markdown代码块中提取JSON并容错修复。
4. 将不稳定字段映射为稳定的领域模型。
5. 对网络、服务、解析错误进行分级处理，支持重试和降级。

## 执行流程

### 1) 先定义输出契约

- 先定义领域实体（例如 `NVCAnalysis`、`InsightReport`），再写解析器。
- 为每个字段定义默认值与容错策略（缺失时回退什么）。
- 明确哪些字段允许 `null`，哪些必须兜底。

### 2) 封装请求层

- 将请求客户端封装在单独 service/client 中。
- 在请求层统一设置：
  - `baseUrl`
  - `Authorization` header
  - `connectTimeout` / `receiveTimeout`
  - `responseType`（SSE时设为 stream）
- 请求体中显式约束输出格式（若后端支持，例如 `response_format: json_object`）。

### 3) 统一处理 SSE 事件流

- 仅处理 `data:` 行，忽略空行和 `[DONE]`。
- 对每个事件 `jsonDecode`，按 `type` 分发处理。
- 仅拼接 `answer` 类型事件的正文。
- 在 `message_end` 或结束事件中提取服务端错误码，提前抛错，不要继续当作成功结果。

### 4) 从答案文本中提取 JSON

- 按优先级提取：
  1. ```json ... ```
  2. ``` ... ```
  3. 第一个完整 `{...}` 对象
  4. 提取失败时回退原文本
- 记录“原始文本长度”和“提取后长度”，便于排障。

### 5) 修复常见 JSON 异常

- 修复已知坏格式（例如 key/value 错位）后再 `jsonDecode`。
- 响应末尾不完整时，截断到最后一个完整 `}` 再解析。
- 修复逻辑保持“白名单化”，只修复已观测问题，避免过度猜测。

### 6) 做字段归一化映射

- 支持同义字段名：
  - 例如 `observation`/`观察`/`事实`
  - `feelings`/`感受`/`情绪`
  - `needs`/`需要`/`需求`
- 支持多形态输入：
  - `List<Map>`
  - `List<String>`
  - `String`（分隔符拆分）
- 对标签类字段做：
  - 分隔符切分（`、,，;；/|`）
  - 去重
  - 清洗前后缀和序号

### 7) 建立错误分级与重试机制

- 区分错误类型：
  - 配置错误（token/project id缺失）
  - 网络错误（timeout）
  - 服务错误（5xx或业务错误码）
  - 解析错误（格式异常）
- 仅对“可恢复错误”重试（超时、暂时性服务失败）。
- 使用退避延迟（例如 `500ms * attempt`）。
- 达到上限后抛出最后一次错误，保留原始上下文。

### 8) 建立降级回退链路

- 先调用主智能体；失败后降级到备用模型/备用供应商。
- 回退策略写在 repository/usecase 层，不散落在 UI。
- 每次降级都记录日志：失败原因、回退目标、最终结果。

### 9) 添加最小验证测试

- 至少覆盖：
  - SSE 正常流（多段 answer 拼接）
  - SSE 错误事件（message_end 错码）
  - Markdown 包裹 JSON 提取
  - 异常 JSON 修复后可解析
  - 同义字段映射与默认值兜底

## 参考实现（本项目）

优先参考以下文件并按需迁移：

- `lib/core/network/coze_ai_service.dart`
  - SSE 解析：`_extractAnswerFromSSE`
  - 答案提取：`_tryExtractAnswer`
  - JSON 提取：`_extractJsonFromText`
  - JSON 修复：`_repairInsightJson`
  - 灵活映射：`_parseFlexibleNVCJson`
  - 错误建模：`CozeAPIException`
- `lib/core/network/doubao_llm_client.dart`
  - 非流式 LLM 请求模板
  - 提示词与 `response_format` 约束
- `lib/data/repositories/ai_repository_impl.dart`
  - 主服务失败后的降级链路（Coze -> Doubao）
- `lib/domain/entities/nvc_analysis.dart`
  - NVC 强类型实体结构
- `lib/domain/entities/insight_report.dart`
  - 洞察报告强类型实体结构

## 实施检查单

- 请求层与解析层是否已解耦？
- 是否能处理“文本 + JSON + SSE混合返回”？
- 是否对字段别名和多形态输入做了归一化？
- 是否只对可恢复错误重试？
- 是否有明确降级路径，且可观测？
- 是否有至少5个解析相关测试样例？
