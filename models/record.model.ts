/**
 * 统一记录模型
 * 支持：碎片记录、日记、周记
 */

export enum RecordType {
  QUICK_NOTE = 'quick_note',    // 碎片记录
  JOURNAL = 'journal',           // 日记
  WEEKLY = 'weekly'              // 周记（暂缓实现）
}

export enum ProcessingMode {
  ONLY_RECORD = 'only_record',   // 仅记录（默认）
  WITH_MOOD = 'with_mood',       // 带情绪标签
  WITH_NVC = 'with_nvc'          // NVC 结构化
}

/**
 * 基础记录接口（所有记录类型的共同字段）
 */
export interface BaseRecord {
  id: string
  type: RecordType
  createdAt: string              // ISO 8601 格式
  updatedAt: string

  // 原始内容（永远保留，可编辑）
  transcription: string          // 转写文本/原文
  audioUrl?: string              // 音频 URL（方案 A 中不存储）

  // 可选字段
  processingMode?: ProcessingMode  // 碎片记录的处理模式
  moods?: string[]                 // 情绪标签 ID 列表
  needs?: string[]                 // 需要标签 ID 列表

  // 用户反馈
  patternFeedback?: 'like' | 'dislike' | 'uncertain'
}

/**
 * 碎片记录（QuickNote）
 * 特点：10-30秒语音，可选结构化
 */
export interface QuickNote extends BaseRecord {
  type: RecordType.QUICK_NOTE
  duration?: number              // 录音时长（秒）

  // NVC 分析结果（可选）
  nvc?: {
    observation: string          // 观察
    feelings: FeelingItem[]      // 感受
    needs: string[]              // 需要 ID 列表
    request?: string             // 请求/行动建议
    userConfirmed: boolean       // 用户是否确认
    userModified: boolean        // 用户是否修改
    generatedAt: string
  }
}

/**
 * 日记（Journal）
 * 特点：长记录，原文优先，AI 旁注辅助
 */
export interface Journal extends BaseRecord {
  type: RecordType.JOURNAL
  title?: string                 // 标题（可选，系统可生成）
  summary?: string               // 摘要（1-2 行）
  date: string                   // YYYY-MM-DD（归属日期）
  referencedFragments?: string[] // 引用的碎片 ID 列表

  // AI 旁注（可选，可被用户否定）
  aiAnnotation?: {
    keyFragments: KeyFragment[]
    emotionPeaks: EmotionPeak[]
    suggestedNeeds: string[]
    microExperiment?: MicroExperiment
    reflectionQuestions?: string[]
    userDismissed: boolean       // 用户是否否定此旁注
    generatedAt: string
  }
}

/**
 * 周记（Weekly） - 暂缓实现
 */
export interface Weekly extends BaseRecord {
  type: RecordType.WEEKLY
  weekRange: string              // "2025-01-13 ~ 2025-01-19"
  referencedRecords?: string[]   // 引用的记录 ID 列表
}

/**
 * 联合类型：所有记录类型
 */
export type Record = QuickNote | Journal | Weekly

/**
 * 感受项（情绪 + 强度）
 */
export interface FeelingItem {
  emotion: string                // 情绪 ID
  intensity: 1 | 2 | 3 | 4 | 5   // 强度
}

/**
 * 关键片段
 */
export interface KeyFragment {
  text: string                   // 原文片段（引用）
  category: 'event' | 'emotion' | 'insight'
}

/**
 * 情绪峰值片段
 */
export interface EmotionPeak {
  text: string                   // 片段原文
  emotion: string                // 情绪 ID
  intensity: number
  localNVC?: {                   // 局部 NVC（可选）
    observation?: string
    feelings?: FeelingItem[]
    needs?: string[]
  }
}

/**
 * 微实验
 */
export interface MicroExperiment {
  trigger: string                // 触发信号
  action30s: string              // 30 秒动作
  needFulfilled: string          // 满足的需要
}
