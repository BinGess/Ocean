/// NVC 分析结果实体（非暴力沟通）
/// 对应 TypeScript 的 NVCAnalysis 模型

import 'package:freezed_annotation/freezed_annotation.dart';

part 'nvc_analysis.freezed.dart';
part 'nvc_analysis.g.dart';

/// 感受强度等级
enum IntensityLevel {
  @JsonValue(1)
  veryLow,
  @JsonValue(2)
  low,
  @JsonValue(3)
  medium,
  @JsonValue(4)
  high,
  @JsonValue(5)
  veryHigh,
}

/// 感受项
@freezed
class Feeling with _$Feeling {
  const factory Feeling({
    required String feeling,
    required IntensityLevel intensity,
  }) = _Feeling;

  factory Feeling.fromJson(Map<String, dynamic> json) =>
      _$FeelingFromJson(json);
}

/// 需要项
@freezed
class Need with _$Need {
  const factory Need({
    required String need,
    required String reason,
  }) = _Need;

  factory Need.fromJson(Map<String, dynamic> json) => _$NeedFromJson(json);
}

/// NVC 分析结果
@freezed
class NVCAnalysis with _$NVCAnalysis {
  const factory NVCAnalysis({
    /// 观察（客观事实描述）
    required String observation,

    /// 感受列表
    required List<Feeling> feelings,

    /// 需要列表
    required List<Need> needs,

    /// 请求（可选）
    String? request,

    /// AI 洞察（可选）
    String? insight,

    /// 分析时间戳
    required DateTime analyzedAt,
  }) = _NVCAnalysis;

  factory NVCAnalysis.fromJson(Map<String, dynamic> json) =>
      _$NVCAnalysisFromJson(json);
}
