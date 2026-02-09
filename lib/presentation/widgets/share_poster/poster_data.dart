/// 海报数据模型
library;

import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';

/// 海报风格枚举
enum PosterStyle {
  /// 心灵票据 - 复古小票风格
  soulReceipt,
  /// 情绪光晕 - 弥散渐变风格
  auraGradient,
  /// 杂志封面 - 极简排版风格
  editorial,
}

/// 海报数据
class PosterData {
  /// 记录ID
  final String recordId;

  /// 日期时间
  final DateTime dateTime;

  /// 主要情绪词（Top 1）
  final String? primaryEmotion;

  /// 所有情绪词
  final List<String> emotions;

  /// 需要列表
  final List<String> needs;

  /// NVC观察
  final String? observation;

  /// NVC感受（带强度）
  final List<Feeling>? feelings;

  /// NVC需要（带原因）
  final List<Need>? nvcNeeds;

  /// AI洞察/建议
  final String? insight;

  /// 原始转写文本
  final String transcription;

  const PosterData({
    required this.recordId,
    required this.dateTime,
    this.primaryEmotion,
    required this.emotions,
    required this.needs,
    this.observation,
    this.feelings,
    this.nvcNeeds,
    this.insight,
    required this.transcription,
  });

  /// 从Record创建PosterData
  factory PosterData.fromRecord(Record record) {
    final moods = record.moods ?? [];
    final needs = record.needs ?? [];

    return PosterData(
      recordId: record.id,
      dateTime: record.createdAt,
      primaryEmotion: moods.isNotEmpty ? moods.first : null,
      emotions: moods,
      needs: needs,
      observation: record.nvc?.observation,
      feelings: record.nvc?.feelings,
      nvcNeeds: record.nvc?.needs,
      insight: record.nvc?.insight,
      transcription: record.transcription,
    );
  }

  /// 获取主要感受词（优先使用NVC feelings）
  String? get mainFeeling {
    if (feelings != null && feelings!.isNotEmpty) {
      // 找到强度最高的感受
      final sorted = [...feelings!]..sort((a, b) =>
        b.intensity.index.compareTo(a.intensity.index));
      return sorted.first.feeling;
    }
    return primaryEmotion;
  }

  /// 获取主要需要词
  String? get mainNeed {
    if (nvcNeeds != null && nvcNeeds!.isNotEmpty) {
      return nvcNeeds!.first.need;
    }
    if (needs.isNotEmpty) {
      return needs.first;
    }
    return null;
  }

  /// 检查是否有足够数据生成海报
  bool get hasEnoughData {
    return emotions.isNotEmpty ||
           (feelings != null && feelings!.isNotEmpty) ||
           observation != null;
  }
}
