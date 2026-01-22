# MindFlow Flutter 应用

> 情绪觉察日记 - 基于非暴力沟通（NVC）框架的情绪管理应用

## 项目概述

MindFlow 是一款帮助用户记录和理解情绪的移动应用，采用非暴力沟通（NVC）框架，通过语音记录、情绪分析和周洞察帮助用户提升情绪觉察能力。

### 核心功能

1. **碎片记录（Quick Notes）**
   - 长按录音快速记录
   - 豆包 ASR 语音转文字
   - 三种处理模式：
     - 仅记录文本
     - 添加情绪标签
     - 完整 NVC 分析

2. **日记（Daily Journal）**
   - 按天聚合显示记录（日卡）
   - 查看每日情绪模式
   - 支持长文本日记

3. **周洞察（Weekly Insights）**
   - AI 分析情绪模式
   - 识别未满足的需要
   - 推荐微实验（小改变）
   - 用户反馈和跟踪

## 技术架构

### Clean Architecture + BLoC

```
lib/
├── core/                    # 核心层
│   ├── constants/          # 常量配置
│   ├── theme/              # 主题和样式
│   ├── network/            # 网络客户端
│   └── di/                 # 依赖注入
├── domain/                  # 领域层（业务逻辑）
│   ├── entities/           # 领域实体
│   ├── repositories/       # 仓储接口
│   └── usecases/          # 用例（待实现）
├── data/                    # 数据层
│   ├── models/             # 数据模型
│   ├── datasources/        # 数据源
│   └── repositories/       # 仓储实现
└── presentation/            # 表现层
    ├── bloc/               # BLoC 状态管理
    ├── screens/            # 页面
    └── widgets/            # 可复用组件
```

### 技术栈

| 类别 | 技术 | 用途 |
|------|------|------|
| 框架 | Flutter SDK | 跨平台移动应用 |
| 状态管理 | flutter_bloc + equatable | BLoC 模式 |
| 本地存储 | hive + hive_flutter | NoSQL 数据库 |
| 网络请求 | dio | HTTP 客户端 |
| WebSocket | web_socket_channel | 实时通信 |
| 音频录制 | record | 录音功能 |
| 依赖注入 | get_it + injectable | DI 容器 |
| 代码生成 | freezed + json_serializable | 不可变模型 |

## 项目结构详解

### 1. Domain Layer（领域层）

#### Entities（实体）

- **Record** - 核心记录实体
  ```dart
  - id: String
  - type: RecordType (quick_note | journal | weekly)
  - transcription: String
  - moods: List<String>?
  - needs: List<String>?
  - nvc: NVCAnalysis?
  ```

- **NVCAnalysis** - NVC 分析结构
  ```dart
  - observation: String (观察)
  - feelings: List<Feeling> (感受)
  - needs: List<String> (需要)
  - request: String? (请求)
  ```

- **WeeklyInsight** - 周洞察
  ```dart
  - emotionalPatterns: List<EmotionalPattern>
  - microExperiments: List<MicroExperiment>
  - needStatistics: List<NeedStatistics>
  ```

#### Repositories（仓储接口）

- `AudioRepository` - 音频录制管理
- `RecordRepository` - 记录 CRUD 操作
- `AIRepository` - AI 分析（转写、NVC）
- `InsightRepository` - 周洞察管理

### 2. Data Layer（数据层）

#### 本地数据源

**HiveDatabase** - 本地数据库管理
- `recordsBox` - 存储所有记录
- `weeklyInsightsBox` - 存储周洞察
- `settingsBox` - 应用设置

#### 远程数据源

**DoubaoDataSource** - 豆包 API 集成
- 语音转文字（ASR WebSocket 二进制协议）
- NVC 分析（LLM REST API）
- 周洞察生成

### 3. Presentation Layer（表现层）

#### BLoC 状态管理

**AudioBloc** - 音频录制状态管理
```dart
Events:
  - AudioCheckPermission
  - AudioStartRecording
  - AudioStopRecording
  - AudioPauseRecording

States:
  - RecordingStatus (initial | recording | paused | completed | error)
  - duration: double
  - audioPath: String?
```

#### Screens（页面）

1. **HomeScreen** - 首页录音
   - 长按录音按钮
   - 实时显示录音时长
   - 权限管理

2. **RecordsScreen** - 碎片记录列表
   - 显示所有快速记录
   - 支持搜索和筛选

3. **JournalScreen** - 日记视图
   - 按天聚合显示
   - 日卡展示

4. **InsightsScreen** - 周洞察
   - 情绪模式可视化
   - 微实验管理

## 豆包 API 集成

### ASR（语音识别）

**DoubaoASRClient** 实现了完整的 WebSocket 二进制协议：

```dart
// 消息格式
[Header (4 bytes)] [Payload Size (4 bytes)] [Payload (N bytes)]

// Header 结构
Byte 0: [协议版本:4bit][Header大小:4bit]
Byte 1: [消息类型:4bit][消息标志:4bit]
Byte 2: [序列化方法:4bit][压缩方法:4bit]
Byte 3: 保留字节
```

**关键特性**：
- ✅ 支持自定义 Headers（Dart WebSocket）
- ✅ 音频分块发送（200ms/chunk = 6400 bytes）
- ✅ 大端序字节编码
- ✅ 实时转写响应

### LLM（大语言模型）

**DoubaoLLMClient** 提供：
- NVC 分析（观察-感受-需要-请求）
- 情绪推荐需要
- 周洞察生成

## 快速开始

### 1. 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- iOS 12.0+ / Android 6.0+

### 2. 安装依赖

```bash
cd flutter_app
flutter pub get
```

### 3. 生成代码

项目使用 `freezed` 和 `hive_generator` 进行代码生成：

```bash
# 生成所有代码
flutter pub run build_runner build --delete-conflicting-outputs

# 或者监听模式（开发时推荐）
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 4. 配置环境变量

创建 `.env` 文件：

```env
DOUBAO_ASR_APP_KEY=your_app_key
DOUBAO_ASR_ACCESS_KEY=your_access_key
DOUBAO_ASR_RESOURCE_ID=your_resource_id
DOUBAO_LLM_API_KEY=your_llm_api_key
```

### 5. 运行应用

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# 指定环境变量
flutter run --dart-define=DOUBAO_ASR_APP_KEY=xxx
```

## 开发指南

### 添加新功能

1. **Domain Layer**: 定义实体和仓储接口
2. **Data Layer**: 实现仓储和数据源
3. **Presentation Layer**: 创建 BLoC 和 UI

### 代码规范

- 使用 `freezed` 创建不可变数据类
- 所有异步操作使用 `Future` / `Stream`
- BLoC 事件和状态使用 `Equatable`
- Repository 使用接口 + 实现分离

### 测试策略

```bash
# 单元测试
flutter test

# Widget 测试
flutter test test/widget_test

# 集成测试
flutter drive --target=test_driver/app.dart
```

## 待实现功能

### 高优先级

- [ ] 完成 `build_runner` 代码生成
- [ ] 实现 Use Cases（领域用例）
- [ ] 完善 UI 组件库
- [ ] 集成豆包 ASR 真实 API
- [ ] 实现情绪和需要词典

### 中优先级

- [ ] 添加单元测试
- [ ] 实现日记编辑功能
- [ ] 周洞察可视化（图表）
- [ ] 离线模式支持
- [ ] 数据导出功能

### 低优先级

- [ ] 国际化（i18n）
- [ ] 深色模式完善
- [ ] 应用内引导教程
- [ ] 数据同步（云端）

## 项目进度

- [x] **Phase 0**: 项目结构搭建 ✅
- [x] **Phase 1**: Domain Layer 实体定义 ✅
- [x] **Phase 2**: Data Layer 仓储实现 ✅
- [x] **Phase 3**: 豆包 API 客户端 ✅
- [x] **Phase 4**: 基础 BLoC 架构 ✅
- [x] **Phase 5**: 主入口和路由 ✅
- [ ] **Phase 6**: 业务逻辑实现（进行中）
- [ ] **Phase 7**: UI 组件开发
- [ ] **Phase 8**: 测试和优化

## 常见问题

### 1. 代码生成失败？

```bash
# 清理并重新生成
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Hive 类型冲突？

确保 `typeId` 在所有 `@HiveType` 中唯一：
- RecordModel: `typeId: 0`
- WeeklyInsightModel: `typeId: 1`

### 3. WebSocket 连接失败？

检查豆包 API 配置：
- App Key、Access Key、Resource ID 是否正确
- 网络权限是否已配置（AndroidManifest.xml / Info.plist）

## 参考资料

- [Flutter 官方文档](https://flutter.dev/docs)
- [BLoC 模式指南](https://bloclibrary.dev)
- [Hive 数据库文档](https://docs.hivedb.dev)
- [豆包 API 文档](https://www.volcengine.com/docs/6561/79818)
- [NVC 非暴力沟通](https://www.cnvc.org)

## 许可证

MIT License

---

**Made with ❤️ by MindFlow Team**
