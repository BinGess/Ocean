/// 日总结实体
/// 由 AI 智能体分析当天记录后生成的情绪总结
library;

class DailySummary {
  /// 日期（只保留年月日）
  final DateTime date;

  /// 情绪关键词（如：如释重负、焦虑、平静）
  final String moodWord;

  /// 一句简短的概括
  final String oneSentence;

  /// 情绪分数 (0-10)
  /// 0 = 非常消极, 10 = 非常积极
  final int score;

  /// 生成时的记录数量
  /// 用于判断是否需要重新生成
  final int recordCount;

  /// 生成时间
  final DateTime generatedAt;

  /// 用户是否已手动设置心情
  /// 如果为 true，则 AI 推荐不会覆盖用户选择
  final bool userOverridden;

  const DailySummary({
    required this.date,
    required this.moodWord,
    required this.oneSentence,
    required this.score,
    required this.recordCount,
    required this.generatedAt,
    this.userOverridden = false,
  });

  /// 从 JSON 创建
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date'] as String),
      moodWord: json['mood_word'] as String,
      oneSentence: json['one_sentence'] as String,
      score: json['score'] as int,
      recordCount: json['record_count'] as int,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      userOverridden: json['user_overridden'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'date': _formatDateKey(date),
      'mood_word': moodWord,
      'one_sentence': oneSentence,
      'score': score,
      'record_count': recordCount,
      'generated_at': generatedAt.toIso8601String(),
      'user_overridden': userOverridden,
    };
  }

  /// 复制并修改
  DailySummary copyWith({
    DateTime? date,
    String? moodWord,
    String? oneSentence,
    int? score,
    int? recordCount,
    DateTime? generatedAt,
    bool? userOverridden,
  }) {
    return DailySummary(
      date: date ?? this.date,
      moodWord: moodWord ?? this.moodWord,
      oneSentence: oneSentence ?? this.oneSentence,
      score: score ?? this.score,
      recordCount: recordCount ?? this.recordCount,
      generatedAt: generatedAt ?? this.generatedAt,
      userOverridden: userOverridden ?? this.userOverridden,
    );
  }

  /// 根据分数获取推荐的心情图片路径
  /// 映射规则：
  /// 0-1: sad.png (低落)
  /// 2-3: tired.png (疲惫)
  /// 4-5: calm.png (平静)
  /// 6-7: loved.png (幸福/愉快)
  /// 8-10: happy.png (开心)
  String get recommendedMoodImagePath {
    if (score <= 1) {
      return 'assets/images/moods/sad.png';
    } else if (score <= 3) {
      return 'assets/images/moods/tired.png';
    } else if (score <= 5) {
      return 'assets/images/moods/calm.png';
    } else if (score <= 7) {
      return 'assets/images/moods/loved.png';
    } else {
      return 'assets/images/moods/happy.png';
    }
  }

  @override
  String toString() {
    return 'DailySummary(date: $date, moodWord: $moodWord, score: $score)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailySummary &&
        other.date == date &&
        other.moodWord == moodWord &&
        other.oneSentence == oneSentence &&
        other.score == score;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        moodWord.hashCode ^
        oneSentence.hashCode ^
        score.hashCode;
  }
}

/// 格式化日期为存储 key
String _formatDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 获取日总结的存储 key
String getDailySummaryKey(DateTime date) {
  return 'daily_summary_${_formatDateKey(date)}';
}
