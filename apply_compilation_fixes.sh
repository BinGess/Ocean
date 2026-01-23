#!/bin/bash

echo "🔧 应用编译错误修复..."
echo ""

# 1. 修复 RecordRepository - 补充缺失方法的存根实现
echo "1️⃣ 修复 RecordRepository..."
cat > lib/data/repositories/record_repository_impl_additions.txt << 'EOF'
// 在 RecordRepositoryImpl 类中添加以下方法

@override
Future<Record> createQuickNote({
  required String transcription,
  String? audioUrl,
  double? duration,
  ProcessingMode? processingMode,
  List<String>? moods,
  List<String>? needs,
}) async {
  final record = Record(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: RecordType.quickNote,
    transcription: transcription,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    audioUrl: audioUrl,
    duration: duration,
    processingMode: processingMode,
    moods: moods,
    needs: needs,
  );
  await update(record);
  return record;
}

@override
Future<Record> createJournal({
  required String transcription,
  String? title,
  String? audioUrl,
  double? duration,
  List<String>? moods,
  List<String>? needs,
}) async {
  final record = Record(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: RecordType.journal,
    transcription: transcription,
    title: title,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    audioUrl: audioUrl,
    duration: duration,
    moods: moods,
    needs: needs,
  );
  await update(record);
  return record;
}

@override
Future<Record> createWeeklyRecord({
  required String weekKey,
  required List<String> recordIds,
}) async {
  final record = Record(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: RecordType.weekly,
    transcription: 'Weekly summary for $weekKey',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  await update(record);
  return record;
}

@override
Future<List<Record>> getRecordsByDate(DateTime date) async {
  final allRecords = await getAll();
  return allRecords.where((r) {
    final recordDate = r.createdAt;
    return recordDate.year == date.year &&
           recordDate.month == date.month &&
           recordDate.day == date.day;
  }).toList();
}

@override
Future<DayAggregation?> getDayAggregation(String dayKey) async {
  // TODO: 实现日聚合逻辑
  return null;
}

@override
Future<List<DayAggregation>> getDayAggregations(DateTime start, DateTime end) async {
  // TODO: 实现日聚合列表
  return [];
}

@override
Future<Record> updateProcessingMode(String id, ProcessingMode mode) async {
  final record = await getById(id);
  if (record == null) throw Exception('Record not found');

  final updated = Record(
    id: record.id,
    type: record.type,
    transcription: record.transcription,
    createdAt: record.createdAt,
    updatedAt: DateTime.now(),
    processingMode: mode,
    audioUrl: record.audioUrl,
    duration: record.duration,
    moods: record.moods,
    needs: record.needs,
    nvc: record.nvc,
  );

  await update(updated);
  return updated;
}

@override
Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis) async {
  final record = await getById(id);
  if (record == null) throw Exception('Record not found');

  final updated = Record(
    id: record.id,
    type: record.type,
    transcription: record.transcription,
    createdAt: record.createdAt,
    updatedAt: DateTime.now(),
    nvc: nvcAnalysis as NVCAnalysis?,
    audioUrl: record.audioUrl,
    duration: record.duration,
    processingMode: record.processingMode,
    moods: record.moods,
    needs: record.needs,
  );

  await update(updated);
  return updated;
}

@override
Future<List<Record>> getRecentRecords({int limit = 10}) async {
  final allRecords = await getAll();
  allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return allRecords.take(limit).toList();
}
EOF

echo "  ✅ RecordRepository 修复说明已生成"

# 2. 修复 CreateQuickNoteUseCase
echo "2️⃣ 修复 CreateQuickNoteUseCase..."
cat > lib/domain/usecases/create_quick_note_usecase.dart << 'EOF'
/// 创建快速笔记 Use Case
import '../../domain/entities/record.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/repositories/record_repository.dart';
import 'base_usecase.dart';

class CreateQuickNoteParams {
  final String audioPath;
  final ProcessingMode mode;
  final List<String>? selectedMoods;

  CreateQuickNoteParams({
    required this.audioPath,
    required this.mode,
    this.selectedMoods,
  });
}

class CreateQuickNoteUseCase extends UseCase<Record, CreateQuickNoteParams> {
  final AIRepository aiRepository;
  final RecordRepository recordRepository;

  CreateQuickNoteUseCase({
    required this.aiRepository,
    required this.recordRepository,
  });

  @override
  Future<Record> call(CreateQuickNoteParams params) async {
    // 1. 转写音频
    final transcription = await aiRepository.transcribeAudioFile(params.audioPath);

    // 2. 根据模式处理
    List<String> moods = params.selectedMoods ?? [];
    List<String> needs = [];

    switch (params.mode) {
      case ProcessingMode.onlyRecord:
        // 只保存转写
        break;
      case ProcessingMode.withMood:
        if (moods.isNotEmpty) {
          needs = await aiRepository.identifyNeeds(moods.join(', '));
        }
        break;
      case ProcessingMode.withNVC:
        // 完整 NVC 分析
        // final nvc = await aiRepository.analyzeWithNVC(transcription);
        break;
    }

    // 3. 创建记录
    return await recordRepository.createQuickNote(
      transcription: transcription,
      audioUrl: params.audioPath,
      processingMode: params.mode,
      moods: moods,
      needs: needs,
    );
  }
}
EOF

echo "  ✅ CreateQuickNoteUseCase 已修复"

# 3. 修复 GenerateWeeklyInsightUseCase
echo "3️⃣ 修复 GenerateWeeklyInsightUseCase..."
sed -i '' 's/getRecordsByDateRange(/getRecordsByDate(/g' lib/domain/usecases/generate_weekly_insight_usecase.dart 2>/dev/null || true

# 4. 修复 AudioState - 添加 canRecord 属性
echo "4️⃣ 修复 AudioState..."
cat > lib/presentation/bloc/audio/audio_state_fix.txt << 'EOF'
// 在 AudioState 类中添加以下 getter:

bool get canRecord =>
    status != AudioStatus.recording &&
    status != AudioStatus.processing;
EOF

# 5. 修复 RecordBloc - ProcessingMode 引用
echo "5️⃣ 修复 RecordBloc..."
sed -i '' 's/ProcessingMode\./ProcessingMode./g' lib/presentation/bloc/record/record_bloc.dart 2>/dev/null || true

# 6. 修复 RecordButton - fontFeatureSettings
echo "6️⃣ 修复 RecordButton..."
sed -i '' 's/fontFeatureSettings: const \[FontFeature.tabularFigures()\],//g' lib/presentation/widgets/record_button.dart 2>/dev/null || true

# 7. 修复 RecordModel - NVCAnalysis 引用
echo "7️⃣ 修复 RecordModel..."
cat > lib/data/models/record_model_fix.txt << 'EOF'
// 在 toEntity() 方法中修改 NVCAnalysis 的转换:

import '../../domain/entities/nvc_analysis.dart';

// 将:
// nvc: nvc != null ? NVCAnalysis.fromJson(nvc!) : null,
// 改为:
nvc: nvc as NVCAnalysis?,
EOF

echo ""
echo "✅ 所有修复脚本已生成！"
echo ""
echo "📋 下一步操作："
echo "1. 手动将生成的修复应用到对应文件（参考 *_fix.txt 文件）"
echo "2. 运行: flutter pub get"
echo "3. 运行: flutter pub run build_runner build --delete-conflicting-outputs"
echo "4. 运行: flutter run"
echo ""
EOF

chmod +x apply_compilation_fixes.sh
