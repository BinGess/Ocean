# 日总结 AI 智能体功能文档

## 概述

日总结功能通过调用 Coze AI 智能体，自动分析用户当天的记录内容，生成情绪关键词、一句话概括和情绪分数，并在每日心情卡片中展示 AI 推荐的心情。

## 需求规格

### 功能需求

1. **情绪分析输出**
   - 情绪关键词 (mood_word): 如"如释重负"、"焦虑"、"平静"等
   - 一句话概括 (one_sentence): 简短描述当天的情绪状态
   - 情绪分数 (score): 0-10 的整数，0 表示非常消极，10 表示非常积极

2. **心情图标映射**
   | 分数范围 | 心情图标 | 描述 |
   |---------|---------|------|
   | 0-1 | sad.png | 低落 |
   | 2-3 | tired.png | 疲惫 |
   | 4-5 | calm.png | 平静 |
   | 6-7 | loved.png | 幸福/愉快 |
   | 8-10 | happy.png | 开心 |

3. **触发条件**
   - 当天记录数 >= 2 条时自动触发生成
   - 新增记录后，如果记录数量增加，自动重新生成

4. **用户交互**
   - AI 推荐心情，用户可手动覆盖
   - 用户手动选择心情后，AI 不会再覆盖用户的选择
   - 在心情卡片中显示 "AI" 标识表明是 AI 推荐

### API 规格

- **端点**: `https://6n23cqs4qb.coze.site/stream_run`
- **项目 ID**: `7610722093646233641`
- **请求方式**: POST (SSE 流式响应)
- **输入格式**:
  ```json
  {
    "project_id": "7610722093646233641",
    "parameters": {
      "records": [
        {
          "record_time": "2024-01-15 09:30:00",
          "content": "记录内容..."
        }
      ]
    },
    "stream": true
  }
  ```
- **输出格式**:
  ```json
  {
    "mood_word": "平静",
    "one_sentence": "今天整体心情平和，有些小收获",
    "score": 6
  }
  ```

## 技术实现

### 文件结构

```
lib/
├── domain/entities/
│   └── daily_summary.dart          # DailySummary 实体类
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # API 配置常量 (修改)
│   ├── network/
│   │   └── coze_ai_service.dart    # Coze API 调用 (修改)
│   ├── services/
│   │   └── daily_summary_service.dart  # 日总结服务 (新增)
│   └── di/
│       └── injection.dart          # 依赖注入 (修改)
└── presentation/screens/records/
    └── records_screen.dart         # 记录页面 UI (修改)
```

### 核心类说明

#### 1. DailySummary 实体 (`lib/domain/entities/daily_summary.dart`)

```dart
class DailySummary {
  final DateTime date;           // 日期
  final String moodWord;         // 情绪关键词
  final String oneSentence;      // 一句话概括
  final int score;               // 情绪分数 (0-10)
  final int recordCount;         // 生成时的记录数量
  final DateTime generatedAt;    // 生成时间
  final bool userOverridden;     // 用户是否已手动覆盖

  /// 根据分数获取推荐的心情图片路径
  String get recommendedMoodImagePath;
}
```

#### 2. DailySummaryService 服务 (`lib/core/services/daily_summary_service.dart`)

```dart
class DailySummaryService {
  static const int minRecordCount = 2;      // 最小记录数
  static const int debounceDelayMs = 5000;  // 防抖延迟 (5秒)

  /// 获取日总结 (从缓存)
  DailySummary? getDailySummary(DateTime date);

  /// 生成日总结
  Future<DailySummary?> generateDailySummary(DateTime date, List<Record> records);

  /// 带防抖的生成方法
  void generateDailySummaryDebounced(DateTime date, List<Record> records, {Function(DailySummary?)? onComplete});

  /// 检查是否需要重新生成
  bool needsRegeneration(DateTime date, int currentRecordCount);

  /// 标记用户已手动覆盖
  Future<void> markUserOverridden(DateTime date);
}
```

#### 3. CozeAIService 扩展 (`lib/core/network/coze_ai_service.dart`)

```dart
/// 日总结记录输入
class DailySummaryRecord {
  final String recordTime;  // 格式: "yyyy-MM-dd HH:mm:ss"
  final String content;
}

/// 生成日总结
Future<DailySummary> generateDailySummary({
  required List<DailySummaryRecord> records,
  required DateTime date,
});
```

### 关键设计决策

#### 1. 防抖机制
- 用户频繁添加记录时，避免频繁调用 API
- 设置 5 秒延迟，只有最后一次请求会被执行
- 使用 Timer 实现，新请求会取消之前的定时器

#### 2. 缓存策略
- 使用 Hive 本地存储缓存日总结
- 存储键格式: `daily_summary_YYYY-MM-DD`
- 首次加载时从缓存读取，避免重复请求

#### 3. 重新生成条件
- 当天没有缓存的日总结
- 当前记录数 > 缓存的记录数（有新记录）
- 记录数 >= 2 条
- 用户未手动覆盖心情

#### 4. 用户覆盖机制
- 用户手动选择心情后，设置 `userOverridden = true`
- AI 不会覆盖已标记的日期
- 保持用户的选择优先级最高

### UI 展示

在每日心情卡片中:
1. 显示 AI 推荐的心情图标（如果用户未手动选择）
2. 显示情绪关键词作为心情标签
3. 显示 "AI" 标识表明是 AI 推荐
4. 显示一句话概括（斜体样式）
5. 生成中显示加载指示器

## 配置说明

### 环境变量 (可选)

在 `.env` 文件中可配置:

```env
COZE_DAILY_SUMMARY_API_TOKEN=your_token_here
COZE_DAILY_SUMMARY_BASE_URL=https://6n23cqs4qb.coze.site
COZE_DAILY_SUMMARY_PROJECT_ID=7610722093646233641
```

如未配置，将使用代码中的默认值。

## 使用流程

```
用户添加记录
    ↓
记录数 >= 2?  ─── 否 ──→ 不触发生成
    │
   是
    ↓
用户已手动选择心情?  ─── 是 ──→ 不覆盖用户选择
    │
   否
    ↓
已有缓存且记录数未增加?  ─── 是 ──→ 使用缓存
    │
   否
    ↓
触发防抖生成 (5秒后执行)
    ↓
调用 Coze API 获取分析结果
    ↓
保存到本地缓存
    ↓
更新 UI 显示 AI 推荐心情
```

## 错误处理

1. **网络错误**: 静默失败，保持现有心情显示
2. **API 响应解析失败**: 记录日志，不影响用户体验
3. **分数超出范围**: 自动截断到 0-10 范围

## 后续优化建议

1. 添加手动刷新日总结的功能
2. 支持查看历史日总结
3. 添加日总结生成失败的重试机制
4. 考虑批量生成历史日期的日总结

## 相关提交

- **提交 ID**: e08864a
- **分支**: claude/improve-recording-button-XV3sj
- **提交信息**: feat: 实现日总结AI智能体功能

## 更新记录

| 日期 | 版本 | 描述 |
|-----|------|------|
| 2026-03-01 | 1.0.0 | 初始实现 |
