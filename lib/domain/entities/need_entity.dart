/// 需要实体（NVC 需要）
/// 对应 TypeScript 的 Need 模型

import 'package:freezed_annotation/freezed_annotation.dart';

part 'need_entity.freezed.dart';
part 'need_entity.g.dart';

/// 需要分类
enum NeedCategory {
  @JsonValue('connection')
  connection, // 连接
  @JsonValue('autonomy')
  autonomy, // 自主
  @JsonValue('meaning')
  meaning, // 意义
  @JsonValue('safety')
  safety, // 安全
  @JsonValue('rest')
  rest, // 休息
  @JsonValue('growth')
  growth, // 成长
}

/// 需要实体
@freezed
class NeedEntity with _$NeedEntity {
  const factory NeedEntity({
    required String id,
    required String label,
    required NeedCategory category,
    required String description,
    List<String>? relatedEmotions,
  }) = _NeedEntity;

  factory NeedEntity.fromJson(Map<String, dynamic> json) =>
      _$NeedEntityFromJson(json);
}
