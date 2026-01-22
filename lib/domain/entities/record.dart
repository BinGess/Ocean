/// 记录实体（领域层）
/// 对应 TypeScript 的 Record 模型

import 'package:freezed_annotation/freezed_annotation.dart';
import 'nvc_analysis.dart';

part 'record.freezed.dart';
part 'record.g.dart';

/// 记录类型
enum RecordType {
  @JsonValue('quick_note')
  quickNote,
  @JsonValue('journal')
  journal,
  @JsonValue('weekly')
  weekly,
}

/// 处理模式
enum ProcessingMode {
  @JsonValue('only_record')
  onlyRecord,
  @JsonValue('with_mood')
  withMood,
  @JsonValue('with_nvc')
  withNVC,
}

/// 统一记录实体
@freezed
class Record with _$Record {
  const factory Record({
    required String id,
    required RecordType type,
    required String transcription,
    required DateTime createdAt,
    required DateTime updatedAt,

    // 可选字段
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,

    // 日记特定字段
    String? title,
    String? summary,
    String? date,
    List<String>? referencedFragments,

    // 周记特定字段
    String? weekRange,
    List<String>? referencedRecords,

    // 用户反馈
    @JsonKey(name: 'pattern_feedback')
    String? patternFeedback, // 'like' | 'dislike' | 'uncertain'
  }) = _Record;

  factory Record.fromJson(Map<String, dynamic> json) => _$RecordFromJson(json);
}

/// 碎片记录（快捷工厂方法）
extension QuickNoteFactory on Record {
  static Record quickNote({
    required String id,
    required String transcription,
    required DateTime createdAt,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
  }) {
    return Record(
      id: id,
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: createdAt,
      updatedAt: createdAt,
      duration: duration,
      processingMode: processingMode,
      moods: moods,
      needs: needs,
      nvc: nvc,
    );
  }
}

/// 日记（快捷工厂方法）
extension JournalFactory on Record {
  static Record journal({
    required String id,
    required String transcription,
    required DateTime createdAt,
    String? title,
    String? summary,
    String? date,
    List<String>? referencedFragments,
  }) {
    return Record(
      id: id,
      type: RecordType.journal,
      transcription: transcription,
      createdAt: createdAt,
      updatedAt: createdAt,
      title: title,
      summary: summary,
      date: date,
      referencedFragments: referencedFragments,
    );
  }
}
