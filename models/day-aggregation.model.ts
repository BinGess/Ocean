/**
 * 按天聚合模型
 * 用于记录库的按天展示
 */

import { Journal, QuickNote } from './record.model'

/**
 * 按天聚合数据
 */
export interface DayAggregation {
  dayKey: string                   // "2025-01-22" (YYYY-MM-DD)
  date: Date                       // 日期对象
  dayOfWeek: string                // "周一"

  // 核心数据
  journal?: Journal                // 当天日记（最多 1 篇）
  quickNotes: QuickNote[]          // 当天碎片（按时间倒序）

  // 统计信息
  stats: DayStats
}

/**
 * 某天的统计信息
 */
export interface DayStats {
  totalRecords: number             // 总记录数
  hasJournal: boolean              // 是否有日记
  topMoods: string[]               // Top 3 情绪 ID
  peakIntensity: number            // 最高强度
  averageIntensity: number         // 平均强度
}

/**
 * 日卡展示配置
 */
export interface DayCardConfig {
  showQuickNotes: boolean          // 是否展示碎片
  expandedByDefault: boolean       // 是否默认展开碎片
}
