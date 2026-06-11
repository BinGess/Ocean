/// 深入分析结果实体。
///
/// 兼容两套结构：
/// - 通用结构（CBT/ACT/DBT/BA）：title + 四段卡片（stuckPoint / groundedUnderstanding /
///   oneSmallStep / steadySentence）。
/// - 自我关怀与滋养（Self-Compassion & Savoring）新结构：face 非空时生效，
///   resonance（开口第一句）/ emotions / observed→truth（翻转卡）/ 一句洞察 /
///   microAction / selfStatement。此时 groundedUnderstanding 承载「一句洞察」，
///   oneSmallStep 承载小动作文案，steadySentence 承载「给自己的一句话」，
///   保证列表摘要卡与旧数据渲染不受影响。
class DeepEmotion {
  final String name;

  /// 0-100
  final int intensity;

  const DeepEmotion({required this.name, required this.intensity});

  factory DeepEmotion.fromJson(Map<String, dynamic> json) {
    return DeepEmotion(
      name: json['name'] as String? ?? '',
      intensity: (json['intensity'] as num?)?.round() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'intensity': intensity};
}

class DeepAnalysisResult {
  final String type;
  final String title;
  final String methodLabel;
  final String theorySource;
  final String overview;
  final String stuckPoint;
  final String groundedUnderstanding;
  final String oneSmallStep;
  final String steadySentence;
  final DateTime analyzedAt;

  // ---- 自我关怀与滋养（新结构）扩展字段，其他方法为 null ----

  /// 'low'（低谷面·自我关怀） | 'high'（高光面·品味滋养）
  final String? face;

  /// 输入信息是否足够做完整拆解；false 时只呈现 resonance + 邀请补充
  final bool enoughSignal;

  /// 开口第一句（反应式共鸣，不宣告）
  final String? resonance;

  final List<DeepEmotion> emotions;

  /// 翻转卡上半：low→「你对自己说的话」 / high→「你匆匆带过的好」
  final String? observedLabel;
  final String? observedValue;

  /// 翻转卡下半：low→「但其实」 / high→「而这份好里」
  final String? truthLabel;
  final String? truthValue;

  /// 'self_kindness' | 'savoring'
  final String? microActionKind;

  const DeepAnalysisResult({
    required this.type,
    required this.title,
    required this.methodLabel,
    required this.theorySource,
    required this.overview,
    required this.stuckPoint,
    required this.groundedUnderstanding,
    required this.oneSmallStep,
    required this.steadySentence,
    required this.analyzedAt,
    this.face,
    this.enoughSignal = true,
    this.resonance,
    this.emotions = const [],
    this.observedLabel,
    this.observedValue,
    this.truthLabel,
    this.truthValue,
    this.microActionKind,
  });

  /// 是否携带结构化拆解（五个深入分析智能体的同构输出）
  /// face 仅自我关怀与滋养有值（low/high），其余方法为 null
  bool get hasStructuredBreakdown => resonance != null || observedValue != null;

  factory DeepAnalysisResult.fromJson(Map<String, dynamic> json) {
    return DeepAnalysisResult(
      type: json['type'] as String,
      title: json['title'] as String,
      methodLabel: json['methodLabel'] as String,
      theorySource: json['theorySource'] as String,
      overview: json['overview'] as String,
      stuckPoint: json['stuckPoint'] as String,
      groundedUnderstanding: json['groundedUnderstanding'] as String,
      oneSmallStep: json['oneSmallStep'] as String,
      steadySentence: json['steadySentence'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      face: json['face'] as String?,
      enoughSignal: json['enoughSignal'] as bool? ?? true,
      resonance: json['resonance'] as String?,
      emotions: (json['emotions'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => DeepEmotion.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList() ??
          const [],
      observedLabel: json['observedLabel'] as String?,
      observedValue: json['observedValue'] as String?,
      truthLabel: json['truthLabel'] as String?,
      truthValue: json['truthValue'] as String?,
      microActionKind: json['microActionKind'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'methodLabel': methodLabel,
      'theorySource': theorySource,
      'overview': overview,
      'stuckPoint': stuckPoint,
      'groundedUnderstanding': groundedUnderstanding,
      'oneSmallStep': oneSmallStep,
      'steadySentence': steadySentence,
      'analyzedAt': analyzedAt.toIso8601String(),
      if (face != null) 'face': face,
      'enoughSignal': enoughSignal,
      if (resonance != null) 'resonance': resonance,
      if (emotions.isNotEmpty)
        'emotions': emotions.map((item) => item.toJson()).toList(),
      if (observedLabel != null) 'observedLabel': observedLabel,
      if (observedValue != null) 'observedValue': observedValue,
      if (truthLabel != null) 'truthLabel': truthLabel,
      if (truthValue != null) 'truthValue': truthValue,
      if (microActionKind != null) 'microActionKind': microActionKind,
    };
  }
}
