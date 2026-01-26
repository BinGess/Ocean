/// 记录数据模型（Hive）
/// 用于本地存储的 Record 模型

import 'package:hive/hive.dart';
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
  });

  /// 从 Domain 实体转换
  factory RecordModel.fromEntity(Record entity) {
    return RecordModel(
      id: entity.id,
      type: entity.type.toString().split('.').last,
      transcription: entity.transcription,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      audioUrl: entity.audioUrl,
      duration: entity.duration,
      processingMode: entity.processingMode?.toString().split('.').last,
      moods: entity.moods,
      needs: entity.needs,
      nvc: entity.nvc != null
          ? {
              'observation': entity.nvc!.observation,
              'feelings': entity.nvc!.feelings.map((f) => f.toJson()).toList(),
              'needs': entity.nvc!.needs.map((n) => n.toJson()).toList(),
              'request': entity.nvc!.request,
              'insight': entity.nvc!.insight,
              'analyzedAt': entity.nvc!.analyzedAt.toIso8601String(),
            }
          : null,
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
      processingMode: processingMode != null
          ? _parseProcessingMode(processingMode!)
          : null,
      moods: moods,
      needs: needs,
      nvc: nvc != null
          ? NVCAnalysis.fromJson(_normalizeJsonMap(nvc!))
          : null,
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
    );
  }
}
