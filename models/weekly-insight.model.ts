/**
 * 周洞察信模型
 */

import { MicroExperiment } from './record.model'

/**
 * 周洞察信
 */
export interface WeeklyInsight {
  id: string
  weekRange: string                // "2025-01-13 ~ 2025-01-19"
  generatedAt: string              // ISO 8601

  // 数据来源说明
  sources: {
    quickNotesCount: number
    journalsCount: number
    totalRecords: number
  }

  // 四块核心内容
  emotionOverview: EmotionOverview
  triggerScenarios: TriggerScenario[]
  patternHypothesis: PatternHypothesis
  microExperiment: MicroExperiment

  // 用户反馈
  patternFeedback?: 'like' | 'dislike' | 'uncertain'
  feedbackNote?: string            // 用户补充说明
}

/**
 * 情绪概览
 */
export interface EmotionOverview {
  topFeelings: Array<{
    emotion: string                // 情绪 ID
    count: number                  // 出现次数
    percentage: number             // 占比
  }>
  intensityPeaks: Array<{
    date: string                   // YYYY-MM-DD
    intensity: number
    emotion: string
  }>
  averageIntensity: number         // 本周平均强度
}

/**
 * 高频触发情境
 */
export interface TriggerScenario {
  scenario: string                 // 情境描述（如"被催进度"）
  commonFeelings: string[]         // 常见情绪 ID（如 ["焦虑", "烦躁"]）
  commonNeeds: string[]            // 常见需要 ID（如 ["自主", "被理解"]）
  evidenceQuote: string            // 证据句（来自原文的引用）
  frequency: number                // 出现频率
}

/**
 * 模式假设
 */
export interface PatternHypothesis {
  statement: string                // 假设陈述（谨慎措辞）
  confidence: 'low' | 'medium' | 'high'  // 置信度
  supportingScenarios: string[]    // 支持此假设的情境
  suggestedReflection?: string     // 建议的反思方向（可选）
}

/**
 * 周洞察生成选项
 */
export interface WeeklyInsightOptions {
  includeEmotionChart: boolean     // 是否包含情绪图表数据
  maxScenarios: number             // 最多显示几个情境
  minRecordsThreshold: number      // 最少记录数阈值（不足时提示）
}
