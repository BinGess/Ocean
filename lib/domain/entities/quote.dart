/// 文案实体
library;

/// 文案分类（4大心理学流派）
enum QuoteCategory {
  mindfulness,       // 正念
  selfCompassion,    // 自我同情
  stoicism,         // 斯多葛派
  nvc,              // NVC非暴力沟通
}

/// 时间偏好
enum TimeContext {
  morning,    // 早晨(5-11)
  afternoon,  // 下午
  evening,    // 晚间(21-3)
  anytime,    // 任何时间
}

/// 文案实体
class Quote {
  final String id;
  final String content;              // 文案内容（中文）
  final String? contentEn;           // 英文版文案（可选，无则回退到 content）
  final String author;               // 作者
  final QuoteCategory category;      // 心理学分类
  final List<String> targetMoods;    // 目标情绪
  final TimeContext timeContext;     // 时间偏好
  final double weight;               // 推荐权重
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.content,
    this.contentEn,
    required this.author,
    required this.category,
    required this.targetMoods,
    required this.timeContext,
    required this.weight,
    required this.createdAt,
  });

  /// 根据语言返回对应文案，无英文版时回退到中文
  String localizedContent(String languageCode) {
    if (languageCode == 'en' && contentEn != null && contentEn!.isNotEmpty) {
      return contentEn!;
    }
    return content;
  }

  /// 从JSON构建Quote对象
  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      content: json['content'] as String,
      contentEn: json['contentEn'] as String?,
      author: json['author'] as String,
      category: _parseCategory(json['category'] as String),
      targetMoods: List<String>.from(json['targetMoods'] as List),
      timeContext: _parseTimeContext(json['timeContext'] as String),
      weight: (json['weight'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static QuoteCategory _parseCategory(String value) {
    return {
      'mindfulness': QuoteCategory.mindfulness,
      'selfCompassion': QuoteCategory.selfCompassion,
      'stoicism': QuoteCategory.stoicism,
      'nvc': QuoteCategory.nvc,
    }[value] ?? QuoteCategory.mindfulness;
  }

  static TimeContext _parseTimeContext(String value) {
    return {
      'morning': TimeContext.morning,
      'afternoon': TimeContext.afternoon,
      'evening': TimeContext.evening,
      'anytime': TimeContext.anytime,
    }[value] ?? TimeContext.anytime;
  }
}
