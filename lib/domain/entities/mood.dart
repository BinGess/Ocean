/// 情绪实体
/// 对应 TypeScript 的 Mood 模型
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mood.freezed.dart';
part 'mood.g.dart';

/// 情绪类型（基于罗素情绪模型）
enum MoodType {
  @JsonValue('HighPleasure')
  highPleasure,
  @JsonValue('MidHighPleasure')
  midHighPleasure,
  @JsonValue('MidPleasure')
  midPleasure,
  @JsonValue('MidLowPleasure')
  midLowPleasure,
  @JsonValue('LowPleasure')
  lowPleasure,
}

/// 情绪配置
@freezed
class MoodConfig with _$MoodConfig {
  const factory MoodConfig({
    required String bgColor,
    required String textColor,
    required String dotColor,
  }) = _MoodConfig;

  factory MoodConfig.fromJson(Map<String, dynamic> json) =>
      _$MoodConfigFromJson(json);
}

/// 情绪实体
@freezed
class Mood with _$Mood {
  const factory Mood({
    required String id,
    required String label,
    required MoodType type,
    required MoodConfig config,
    String? description,
  }) = _Mood;

  factory Mood.fromJson(Map<String, dynamic> json) => _$MoodFromJson(json);
}
