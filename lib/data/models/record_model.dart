/// 记录数据模型（Hive）
/// 用于本地存储的 Record 模型
library;

import 'package:hive/hive.dart';
import '../../domain/entities/deep_analysis_result.dart';
import '../../domain/entities/record.dart';
import '../../domain/entities/nvc_analysis.dart';

part 'record_model.g.dart';

@HiveType(typeId: 0)
class RecordModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'quick_note' | 'journal' | 'weekly'

  @HiveField(2)
  final String transcription;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final String? audioUrl;

  @HiveField(6)
  final double? duration;

  @HiveField(7)
  final String? processingMode;

  @HiveField(8)
  final List<String>? moods;

  @HiveField(9)
  final List<String>? needs;

  @HiveField(10)
  final Map<String, dynamic>? nvc;

  @HiveField(11)
  final String? title;

  @HiveField(12)
  final String? summary;

  @HiveField(13)
  final String? date;

  @HiveField(14)
  final List<String>? referencedFragments;

  @HiveField(15)
  final String? weekRange;

  @HiveField(16)
  final List<String>? referencedRecords;

  @HiveField(17)
  final String? patternFeedback;

  @HiveField(18)
  final List<Map<String, dynamic>>? deepAnalyses;

  RecordModel({
    required this.id,
    required this.type,
    required this.transcription,
    required this.createdAt,
    required this.updatedAt,
    this.audioUrl,
    this.duration,
    this.processingMode,
    this.moods,
    this.needs,
    this.nvc,
    this.title,
    this.summary,
    this.date,
    this.referencedFragments,
    this.weekRange,
    this.referencedRecords,
    this.patternFeedback,
    this.deepAnalyses,
  });

  /// 从 Domain 实体转换
  factory RecordModel.fromEntity(Record entity) {
    return RecordModel(
      id: entity.id,
      type: _recordTypeToJson(entity.type),
      transcription: entity.transcription,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      audioUrl: entity.audioUrl,
      duration: entity.duration,
      processingMode: entity.processingMode == null
          ? null
          : _processingModeToJson(entity.processingMode!),
      moods: entity.moods,
      needs: entity.needs,
      nvc: entity.nvc != null
          ? {
              'observation': entity.nvc!.observation,
              'feelings': entity.nvc!.feelings.map((f) => f.toJson()).toList(),
              'needs': entity.nvc!.needs.map((n) => n.toJson()).toList(),
              'request': entity.nvc!.request,
              'insight': entity.nvc!.insight,
              // NVC 智能体的分诊结果；缺失会让历史记录的推荐徽章回退到关键词路由
              'recommendedMethod': entity.nvc!.recommendedMethod,
              'analyzedAt': entity.nvc!.analyzedAt.toIso8601String(),
            }
          : null,
      title: entity.title,
      summary: entity.summary,
      date: entity.date,
      referencedFragments: entity.referencedFragments,
      weekRange: entity.weekRange,
      referencedRecords: entity.referencedRecords,
      patternFeedback: entity.patternFeedback,
      deepAnalyses: entity.deepAnalyses?.map((item) => item.toJson()).toList(),
    );
  }

  /// 转换为 Domain 实体
  Record toEntity() {
    return Record(
      id: id,
      type: _parseRecordType(type),
      transcription: transcription,
      createdAt: createdAt,
      updatedAt: updatedAt,
      audioUrl: audioUrl,
      duration: duration,
      processingMode:
          processingMode != null ? _parseProcessingMode(processingMode!) : null,
      moods: moods,
      needs: needs,
      nvc: nvc != null ? NVCAnalysis.fromJson(_normalizeJsonMap(nvc!)) : null,
      title: title,
      summary: summary,
      date: date,
      referencedFragments: referencedFragments,
      weekRange: weekRange,
      referencedRecords: referencedRecords,
      patternFeedback: patternFeedback,
      deepAnalyses: deepAnalyses
          ?.map((item) => DeepAnalysisResult.fromJson(_normalizeJsonMap(item)))
          .toList(),
    );
  }

  Map<String, dynamic> _normalizeJsonMap(Map<dynamic, dynamic> source) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        normalized[key] = _normalizeJsonMap(Map<dynamic, dynamic>.from(value));
      } else if (value is List) {
        normalized[key] = value.map((item) {
          if (item is Map) {
            return _normalizeJsonMap(Map<dynamic, dynamic>.from(item));
          }
          if (item is List) {
            return item.map((nested) {
              if (nested is Map) {
                return _normalizeJsonMap(Map<dynamic, dynamic>.from(nested));
              }
              return nested;
            }).toList();
          }
          return item;
        }).toList();
      } else {
        normalized[key] = value;
      }
    }
    return normalized;
  }

  /// 解析 RecordType
  RecordType _parseRecordType(String type) {
    switch (type) {
      case 'quick_note':
        return RecordType.quickNote;
      case 'journal':
        return RecordType.journal;
      case 'weekly':
        return RecordType.weekly;
      default:
        return RecordType.quickNote;
    }
  }

  /// 解析 ProcessingMode
  ProcessingMode _parseProcessingMode(String mode) {
    switch (mode) {
      case 'only_record':
        return ProcessingMode.onlyRecord;
      case 'with_mood':
        return ProcessingMode.withMood;
      case 'with_nvc':
        return ProcessingMode.withNVC;
      default:
        return ProcessingMode.onlyRecord;
    }
  }

  static String _recordTypeToJson(RecordType type) {
    switch (type) {
      case RecordType.quickNote:
        return 'quick_note';
      case RecordType.journal:
        return 'journal';
      case RecordType.weekly:
        return 'weekly';
    }
  }

  static String _processingModeToJson(ProcessingMode mode) {
    switch (mode) {
      case ProcessingMode.onlyRecord:
        return 'only_record';
      case ProcessingMode.withMood:
        return 'with_mood';
      case ProcessingMode.withNVC:
        return 'with_nvc';
    }
  }

  /// 复制并修改
  RecordModel copyWith({
    String? id,
    String? type,
    String? transcription,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? audioUrl,
    double? duration,
    String? processingMode,
    List<String>? moods,
    List<String>? needs,
    Map<String, dynamic>? nvc,
    String? title,
    String? summary,
    String? date,
    List<String>? referencedFragments,
    String? weekRange,
    List<String>? referencedRecords,
    String? patternFeedback,
    List<Map<String, dynamic>>? deepAnalyses,
  }) {
    return RecordModel(
      id: id ?? this.id,
      type: type ?? this.type,
      transcription: transcription ?? this.transcription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      processingMode: processingMode ?? this.processingMode,
      moods: moods ?? this.moods,
      needs: needs ?? this.needs,
      nvc: nvc ?? this.nvc,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      date: date ?? this.date,
      referencedFragments: referencedFragments ?? this.referencedFragments,
      weekRange: weekRange ?? this.weekRange,
      referencedRecords: referencedRecords ?? this.referencedRecords,
      patternFeedback: patternFeedback ?? this.patternFeedback,
      deepAnalyses: deepAnalyses ?? this.deepAnalyses,
    );
  }
}
