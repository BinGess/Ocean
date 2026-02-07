// ignore_for_file: invalid_annotation_target

/// 洞察报告实体
/// 对应 Coze AI 智能体返回的洞察报告格式
library;


import 'package:freezed_annotation/freezed_annotation.dart';

part 'insight_report.freezed.dart';
part 'insight_report.g.dart';

/// 情绪概览
@freezed
class EmotionOverview with _$EmotionOverview {
  const factory EmotionOverview({
    /// 总结内容（约300字以内）
    required String summary,
  }) = _EmotionOverview;

  factory EmotionOverview.fromJson(Map<String, dynamic> json) =>
      _$EmotionOverviewFromJson(json);
}

/// 高频情境
@freezed
class HighFrequencyEmotion with _$HighFrequencyEmotion {
  const factory HighFrequencyEmotion({
    /// 记录内容
    required String content,
    /// 时间（如：周四 14:15）
    required String time,
  }) = _HighFrequencyEmotion;

  factory HighFrequencyEmotion.fromJson(Map<String, dynamic> json) =>
      _$HighFrequencyEmotionFromJson(json);
}

/// 高亮标签
@freezed
class HighlightTag with _$HighlightTag {
  const factory HighlightTag({
    /// 标签键（如：trigger, value）
    required String key,
    /// 标签值
    required String value,
  }) = _HighlightTag;

  factory HighlightTag.fromJson(Map<String, dynamic> json) =>
      _$HighlightTagFromJson(json);
}

/// 模式假设（潜在需求挖掘）
@freezed
class PatternHypothesis with _$PatternHypothesis {
  const factory PatternHypothesis({
    /// 模板文本（如：看起来 {trigger} 似乎触发了你内心对 {need} 的强烈需要）
    required String text,
    /// 高亮标签列表
    @JsonKey(name: 'highlight_tags') required List<HighlightTag> highlightTags,
  }) = _PatternHypothesis;

  factory PatternHypothesis.fromJson(Map<String, dynamic> json) =>
      _$PatternHypothesisFromJson(json);
}

/// 行动建议
@freezed
class ActionSuggestion with _$ActionSuggestion {
  const factory ActionSuggestion({
    /// 建议标题
    required String title,
    /// 建议内容
    required String content,
  }) = _ActionSuggestion;

  factory ActionSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ActionSuggestionFromJson(json);
}

/// 洞察报告（完整的周洞察报告）
@freezed
class InsightReport with _$InsightReport {
  const factory InsightReport({
    /// 报告ID
    required String id,

    /// 报告类型（如：每周洞察报告）
    @JsonKey(name: 'report_type') required String reportType,

    /// 情绪概览
    @JsonKey(name: 'emotion_overview') required EmotionOverview emotionOverview,

    /// 高频情境列表
    @JsonKey(name: 'high_frequency_emotions') required List<HighFrequencyEmotion> highFrequencyEmotions,

    /// 模式假设（潜在需求挖掘）
    @JsonKey(name: 'pattern_hypothesis') required PatternHypothesis patternHypothesis,

    /// 行动建议列表
    @JsonKey(name: 'action_suggestions') required List<ActionSuggestion> actionSuggestions,

    /// 周范围（如：2026-01-27 ~ 2026-02-02）
    @JsonKey(name: 'week_range') required String weekRange,

    /// 创建时间
    @JsonKey(name: 'created_at') required DateTime createdAt,

    /// 引用的记录数
    @JsonKey(name: 'record_count') int? recordCount,
  }) = _InsightReport;

  factory InsightReport.fromJson(Map<String, dynamic> json) =>
      _$InsightReportFromJson(json);
}

/// 洞察请求记录（发送给 AI 的记录格式）
@freezed
class InsightRequestRecord with _$InsightRequestRecord {
  const factory InsightRequestRecord({
    /// 记录时间（如：2026-01-22 21:30）
    @JsonKey(name: 'record_time') required String recordTime,
    /// 记录内容
    required String content,
  }) = _InsightRequestRecord;

  factory InsightRequestRecord.fromJson(Map<String, dynamic> json) =>
      _$InsightRequestRecordFromJson(json);

  @override
  Map<String, dynamic> toJson() => {
    'record_time': recordTime,
    'content': content,
  };
}
