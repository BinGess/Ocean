# MindFlow Flutter 项目架构规划

## 📋 项目概述

**项目名称**: MindFlow - 情绪觉察记录 App
**技术栈**: Flutter + Dart
**目标平台**: iOS + Android
**架构模式**: Clean Architecture + BLoC/Riverpod

---

## 🏗️ 推荐的 Flutter 项目结构

```
mindflow_flutter/
├── lib/
│   ├── main.dart                    # 应用入口
│   │
│   ├── core/                        # 核心层（基础设施）
│   │   ├── constants/               # 常量配置
│   │   │   ├── app_constants.dart
│   │   │   ├── emotions.dart        # 情绪词库
│   │   │   └── needs.dart          # 需要词库
│   │   ├── theme/                   # 主题配置
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_theme.dart
│   │   ├── utils/                   # 工具函数
│   │   │   ├── date_utils.dart
│   │   │   ├── mood_utils.dart
│   │   │   └── need_utils.dart
│   │   ├── error/                   # 错误处理
│   │   │   ├── failures.dart
│   │   │   └── exceptions.dart
│   │   └── network/                 # 网络配置
│   │       ├── dio_client.dart
│   │       └── websocket_client.dart
│   │
│   ├── data/                        # 数据层
│   │   ├── models/                  # 数据模型（与 API 对应）
│   │   │   ├── record_model.dart
│   │   │   ├── nvc_model.dart
│   │   │   ├── mood_model.dart
│   │   │   ├── need_model.dart
│   │   │   ├── journal_model.dart
│   │   │   └── weekly_insight_model.dart
│   │   ├── datasources/             # 数据源
│   │   │   ├── local/               # 本地数据源
│   │   │   │   ├── record_local_datasource.dart
│   │   │   │   └── database_helper.dart  # SQLite/Hive
│   │   │   └── remote/              # 远程数据源
│   │   │       ├── doubao_asr_datasource.dart
│   │   │       └── doubao_llm_datasource.dart
│   │   └── repositories/            # 仓储实现
│   │       ├── record_repository_impl.dart
│   │       ├── audio_repository_impl.dart
│   │       └── ai_repository_impl.dart
│   │
│   ├── domain/                      # 领域层（业务逻辑）
│   │   ├── entities/                # 实体（纯业务对象）
│   │   │   ├── record.dart
│   │   │   ├── quick_note.dart
│   │   │   ├── journal.dart
│   │   │   ├── nvc_analysis.dart
│   │   │   └── weekly_insight.dart
│   │   ├── repositories/            # 仓储接口
│   │   │   ├── record_repository.dart
│   │   │   ├── audio_repository.dart
│   │   │   └── ai_repository.dart
│   │   └── usecases/                # 用例（业务用例）
│   │       ├── create_quick_note.dart
│   │       ├── transcribe_audio.dart
│   │       ├── analyze_with_nvc.dart
│   │       ├── get_day_aggregation.dart
│   │       └── generate_weekly_insight.dart
│   │
│   ├── presentation/                # 表现层（UI）
│   │   ├── bloc/                    # BLoC 状态管理
│   │   │   ├── audio/
│   │   │   │   ├── audio_bloc.dart
│   │   │   │   ├── audio_event.dart
│   │   │   │   └── audio_state.dart
│   │   │   ├── record/
│   │   │   │   ├── record_bloc.dart
│   │   │   │   ├── record_event.dart
│   │   │   │   └── record_state.dart
│   │   │   └── day_feed/
│   │   │       ├── day_feed_bloc.dart
│   │   │       ├── day_feed_event.dart
│   │   │       └── day_feed_state.dart
│   │   ├── screens/                 # 页面
│   │   │   ├── home/
│   │   │   │   ├── home_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── record_button.dart
│   │   │   ├── records/
│   │   │   │   ├── records_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── day_card.dart
│   │   │   │       └── quick_note_card.dart
│   │   │   ├── journal/
│   │   │   │   ├── journal_editor_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── ai_annotation.dart
│   │   │   └── insights/
│   │   │       ├── weekly_insight_screen.dart
│   │   │       └── widgets/
│   │   │           └── insight_card.dart
│   │   └── widgets/                 # 通用组件
│   │       ├── common/
│   │       │   ├── loading_spinner.dart
│   │       │   ├── custom_button.dart
│   │       │   └── custom_modal.dart
│   │       └── processing_choice_modal.dart
│   │
│   └── injection_container.dart     # 依赖注入配置
│
├── test/                            # 测试
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── assets/                          # 资源文件
│   ├── images/
│   └── fonts/
│
├── pubspec.yaml                     # 依赖配置
└── README.md

```

---

## 🎯 状态管理选型：BLoC Pattern

### 为什么选择 BLoC？

| 特性 | BLoC | Riverpod | Provider |
|------|------|----------|----------|
| **学习曲线** | 中等 | 陡峭 | 简单 |
| **可测试性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **代码组织** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **官方推荐** | ✅ | ✅ | ✅ |
| **大型项目** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**推荐使用 BLoC**：
- ✅ 明确的单向数据流
- ✅ 业务逻辑与 UI 完全分离
- ✅ 易于测试
- ✅ 适合复杂业务场景（NVC 分析、周洞察）

---

## 📦 核心依赖（pubspec.yaml）

```yaml
name: mindflow
description: 情绪觉察记录 App

dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5

  # 依赖注入
  get_it: ^7.6.0
  injectable: ^2.3.0

  # 数据持久化
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.1

  # 网络请求
  dio: ^5.4.0
  web_socket_channel: ^2.4.0

  # 音频录制
  record: ^5.0.1
  audioplayers: ^5.2.1

  # 工具类
  uuid: ^4.2.2
  intl: ^0.18.1
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

  # 路由
  go_router: ^13.0.0

  # UI
  flutter_svg: ^2.0.9
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # 代码生成
  build_runner: ^2.4.7
  freezed: ^2.4.5
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1
  injectable_generator: ^2.4.1

  # 测试
  mockito: ^5.4.4
  bloc_test: ^9.1.5
```

---

## 📊 TypeScript → Dart 代码对照

### 1. 数据模型

#### TypeScript (现有)
```typescript
export interface QuickNote {
  id: string
  type: RecordType.QUICK_NOTE
  transcription: string
  duration?: number
  processingMode?: ProcessingMode
  moods?: string[]
  needs?: string[]
  nvc?: NVCAnalysis
  createdAt: string
  updatedAt: string
}
```

#### Dart (目标)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'quick_note.freezed.dart';
part 'quick_note.g.dart';

@freezed
class QuickNote with _$QuickNote {
  const factory QuickNote({
    required String id,
    required RecordType type,
    required String transcription,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _QuickNote;

  factory QuickNote.fromJson(Map<String, dynamic> json) =>
      _$QuickNoteFromJson(json);
}
```

### 2. Zustand Store → BLoC

#### TypeScript (Zustand)
```typescript
export const useRecordStore = create<RecordState>((set, get) => ({
  currentRecord: null,
  isProcessing: false,

  createQuickNote: async (audioBlob, mode) => {
    set({ isProcessing: true })
    // ...逻辑
    set({ currentRecord: note, isProcessing: false })
  }
}))
```

#### Dart (BLoC)
```dart
// record_event.dart
abstract class RecordEvent extends Equatable {
  const RecordEvent();
}

class CreateQuickNote extends RecordEvent {
  final File audioFile;
  final ProcessingMode mode;

  const CreateQuickNote(this.audioFile, this.mode);

  @override
  List<Object> get props => [audioFile, mode];
}

// record_state.dart
abstract class RecordState extends Equatable {
  const RecordState();
}

class RecordInitial extends RecordState {
  @override
  List<Object> get props => [];
}

class RecordProcessing extends RecordState {
  final String stage; // 'transcribing', 'analyzing', 'saving'

  const RecordProcessing(this.stage);

  @override
  List<Object> get props => [stage];
}

class RecordSuccess extends RecordState {
  final QuickNote record;

  const RecordSuccess(this.record);

  @override
  List<Object> get props => [record];
}

class RecordFailure extends RecordState {
  final String message;

  const RecordFailure(this.message);

  @override
  List<Object> get props => [message];
}

// record_bloc.dart
class RecordBloc extends Bloc<RecordEvent, RecordState> {
  final CreateQuickNoteUseCase createQuickNoteUseCase;
  final TranscribeAudioUseCase transcribeAudioUseCase;
  final AnalyzeWithNVCUseCase analyzeWithNVCUseCase;

  RecordBloc({
    required this.createQuickNoteUseCase,
    required this.transcribeAudioUseCase,
    required this.analyzeWithNVCUseCase,
  }) : super(RecordInitial()) {
    on<CreateQuickNote>(_onCreateQuickNote);
  }

  Future<void> _onCreateQuickNote(
    CreateQuickNote event,
    Emitter<RecordState> emit,
  ) async {
    emit(const RecordProcessing('transcribing'));

    // 1. 转写音频
    final transcriptionResult = await transcribeAudioUseCase(event.audioFile);

    await transcriptionResult.fold(
      (failure) async => emit(RecordFailure(failure.message)),
      (transcription) async {
        // 2. NVC 分析（如果需要）
        if (event.mode == ProcessingMode.withNVC) {
          emit(const RecordProcessing('analyzing'));
          final nvcResult = await analyzeWithNVCUseCase(transcription);

          await nvcResult.fold(
            (failure) async => emit(RecordFailure(failure.message)),
            (nvc) async {
              // 3. 创建记录
              emit(const RecordProcessing('saving'));
              final createResult = await createQuickNoteUseCase(
                transcription: transcription,
                mode: event.mode,
                nvc: nvc,
              );

              createResult.fold(
                (failure) => emit(RecordFailure(failure.message)),
                (record) => emit(RecordSuccess(record)),
              );
            },
          );
        } else {
          // 仅记录模式
          emit(const RecordProcessing('saving'));
          final createResult = await createQuickNoteUseCase(
            transcription: transcription,
            mode: event.mode,
          );

          createResult.fold(
            (failure) => emit(RecordFailure(failure.message)),
            (record) => emit(RecordSuccess(record)),
          );
        }
      },
    );
  }
}
```

### 3. React 组件 → Flutter Widget

#### TypeScript (React)
```typescript
export const RecordButton: React.FC = () => {
  const { isRecording, startRecording, stopRecording } = useAudioRecorder()

  return (
    <button onPointerDown={startRecording} onPointerUp={stopRecording}>
      {isRecording ? <Square /> : <Mic />}
    </button>
  )
}
```

#### Dart (Flutter)
```dart
class RecordButton extends StatelessWidget {
  const RecordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isRecording = state is AudioRecording;

        return GestureDetector(
          onLongPressStart: (_) {
            context.read<AudioBloc>().add(const StartRecording());
          },
          onLongPressEnd: (_) {
            context.read<AudioBloc>().add(const StopRecording());
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? Colors.red : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 36,
            ),
          ),
        );
      },
    );
  }
}
```

---

## 🗄️ 数据持久化：Hive

### 为什么选择 Hive？

| 特性 | Hive | SQLite | SharedPreferences |
|------|------|--------|-------------------|
| **性能** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **类型安全** | ✅ | ❌ | ❌ |
| **NoSQL** | ✅ | ❌ | ❌ |
| **易用性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **复杂查询** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ |

**Hive 示例**：
```dart
// 初始化
await Hive.initFlutter();
Hive.registerAdapter(QuickNoteAdapter());
await Hive.openBox<QuickNote>('quick_notes');

// 保存
final box = Hive.box<QuickNote>('quick_notes');
await box.put(note.id, note);

// 查询
final allNotes = box.values.toList();
final todayNotes = box.values.where((note) =>
  note.createdAt.day == DateTime.now().day
).toList();
```

---

## 🌐 豆包 API 集成（Dart）

### WebSocket 二进制协议

```dart
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class DoubaoASRClient {
  late WebSocketChannel _channel;
  final String appKey;
  final String accessKey;
  final String resourceId;

  DoubaoASRClient({
    required this.appKey,
    required this.accessKey,
    required this.resourceId,
  });

  Future<String> transcribe(File audioFile) async {
    // 1. 建立 WebSocket 连接（带自定义 Header）
    final uri = Uri.parse(
      'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async'
    );

    // ✅ Dart 的 WebSocket 支持自定义 Header！
    _channel = WebSocketChannel.connect(
      uri,
      protocols: [],
    );

    // 发送鉴权信息（可以通过第一个消息发送）
    final connectId = const Uuid().v4();

    // 2. 发送 Full Client Request
    final config = {
      'user': {'uid': 'user_${DateTime.now().millisecondsSinceEpoch}'},
      'audio': {
        'format': 'wav',
        'rate': 16000,
        'bits': 16,
        'channel': 1,
      },
      'request': {
        'model_name': 'bigmodel',
        'enable_itn': true,
        'enable_punc': true,
      },
    };

    final configMessage = _buildMessage(
      MessageType.fullClientRequest,
      MessageFlags.none,
      SerializationMethod.json,
      CompressionMethod.none,
      utf8.encode(jsonEncode(config)),
    );

    _channel.sink.add(configMessage);

    // 3. 发送音频数据（分包）
    final audioBytes = await audioFile.readAsBytes();
    await _sendAudioInChunks(audioBytes);

    // 4. 接收识别结果
    String transcription = '';
    await for (final message in _channel.stream) {
      final result = _parseServerResponse(message as Uint8List);
      if (result['text'] != null) {
        transcription = result['text'];
      }
      if (result['isFinal'] == true) {
        break;
      }
    }

    _channel.sink.close();
    return transcription;
  }

  Uint8List _buildMessage(
    int messageType,
    int flags,
    int serialization,
    int compression,
    List<int> payload,
  ) {
    // Header（4 字节）
    final header = Uint8List(4);
    header[0] = (0b0001 << 4) | 0b0001; // Version + Header Size
    header[1] = (messageType << 4) | flags;
    header[2] = (serialization << 4) | compression;
    header[3] = 0x00; // Reserved

    // Payload Size（4 字节，大端）
    final payloadSize = Uint8List(4);
    final size = payload.length;
    payloadSize[0] = (size >> 24) & 0xFF;
    payloadSize[1] = (size >> 16) & 0xFF;
    payloadSize[2] = (size >> 8) & 0xFF;
    payloadSize[3] = size & 0xFF;

    // 组合消息
    final builder = BytesBuilder();
    builder.add(header);
    builder.add(payloadSize);
    builder.add(payload);

    return builder.toBytes();
  }

  Future<void> _sendAudioInChunks(Uint8List audioData) async {
    const chunkSize = 6400; // 200ms @ 16kHz 16bit mono
    for (int offset = 0; offset < audioData.length; offset += chunkSize) {
      final end = (offset + chunkSize < audioData.length)
          ? offset + chunkSize
          : audioData.length;
      final chunk = audioData.sublist(offset, end);
      final isLast = end >= audioData.length;

      final message = _buildMessage(
        MessageType.audioOnlyRequest,
        isLast ? MessageFlags.lastPacket : MessageFlags.none,
        SerializationMethod.none,
        CompressionMethod.none,
        chunk,
      );

      _channel.sink.add(message);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Map<String, dynamic> _parseServerResponse(Uint8List data) {
    // 解析二进制响应（与 TypeScript 版本逻辑相同）
    // ...
    return {'text': '转写结果', 'isFinal': true};
  }
}

// 消息类型常量
class MessageType {
  static const int fullClientRequest = 0b0001;
  static const int audioOnlyRequest = 0b0010;
  static const int fullServerResponse = 0b1001;
  static const int errorMessage = 0b1111;
}

class MessageFlags {
  static const int none = 0b0000;
  static const int lastPacket = 0b0010;
}

class SerializationMethod {
  static const int none = 0b0000;
  static const int json = 0b0001;
}

class CompressionMethod {
  static const int none = 0b0000;
  static const int gzip = 0b0001;
}
```

---

## 📱 UI 设计（Flutter Material/Cupertino）

### 主题配置

```dart
// app_theme.dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: const Color(0xFF48697A),
    scaffoldBackgroundColor: const Color(0xFFFBFAF9),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF48697A),
      secondary: Color(0xFF8D9D86),
      tertiary: Color(0xFFB28C7F),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF48697A),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Color(0xFF3F4652),
      ),
    ),
  );
}
```

---

## 🚀 实施步骤（4-6周计划）

### Week 1: 项目搭建和核心架构
- ✅ Day 1-2: 创建 Flutter 项目，配置依赖
- ✅ Day 3-4: 创建数据模型（Freezed）
- ✅ Day 5: 配置 Hive 数据库
- ✅ Day 6-7: 创建 BLoC 架构骨架

### Week 2: 数据层和业务逻辑
- ✅ Day 8-10: 实现数据源（Local + Remote）
- ✅ Day 11-12: 实现 Repository
- ✅ Day 13-14: 实现 Use Cases

### Week 3: 音频和 API 集成
- ✅ Day 15-16: 实现音频录制功能
- ✅ Day 17-19: 集成豆包 ASR API
- ✅ Day 20-21: 集成豆包大模型 API

### Week 4: UI 实现（Phase 1-3）
- ✅ Day 22-23: Home 页面 + 录音按钮
- ✅ Day 24-25: 碎片记录流程
- ✅ Day 26-28: 处理选择和 NVC 展示

### Week 5: UI 实现（Phase 4-5）
- ✅ Day 29-31: Records 页面（按天聚合）
- ✅ Day 32-33: 日记编辑器
- ✅ Day 34-35: AI 旁注功能

### Week 6: UI 实现（Phase 6）+ 测试
- ✅ Day 36-38: 周洞察信页面
- ✅ Day 39-40: 整体测试和优化
- ✅ Day 41-42: 打包和发布准备

---

## 📄 下一步行动

我可以为你：

### **选项 1：立即创建 Flutter 项目骨架**
- 创建完整的目录结构
- 配置 `pubspec.yaml`
- 创建基础数据模型（Dart）
- 创建 BLoC 架构示例

### **选项 2：先创建详细的代码映射文档**
- TypeScript → Dart 逐个文件的对照表
- 每个功能模块的 Dart 实现方案
- 完整的 API 集成代码

### **选项 3：保留 React 版本作为参考，你自己实现 Flutter**
- React 版本作为架构文档
- 我提供 Dart 代码片段供参考

---

**你希望我做什么？**

1️⃣ **立即创建 Flutter 项目**（我帮你搭建完整骨架）
2️⃣ **先创建详细文档**（代码映射 + 实施指南）
3️⃣ **我继续完成 React Phase 4-6**（作为 Flutter 蓝图）

请选择！🚀
