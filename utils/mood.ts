/**
 * 情绪相关工具函数
 */

import { Mood, FeelingItem } from '../models'
import { EMOTIONS, getEmotionById } from '../config/emotions'

/**
 * 获取情绪的颜色类
 */
export function getMoodColor(moodId: string): {
  bg: string
  text: string
  dot: string
} {
  const emotion = getEmotionById(moodId)
  return emotion?.color || {
    bg: 'bg-gray-100',
    text: 'text-gray-600',
    dot: 'bg-gray-400'
  }
}

/**
 * 获取情绪的标签
 */
export function getMoodLabel(moodId: string): string {
  const emotion = getEmotionById(moodId)
  return emotion?.label || '未知情绪'
}

/**
 * 获取多个情绪的标签（用逗号分隔）
 */
export function getMoodLabels(moodIds: string[]): string {
  return moodIds.map(id => getMoodLabel(id)).join('、')
}

/**
 * 根据强度获取描述
 */
export function getIntensityLabel(intensity: number): string {
  if (intensity === 1) return '很轻微'
  if (intensity === 2) return '轻微'
  if (intensity === 3) return '中等'
  if (intensity === 4) return '强烈'
  if (intensity === 5) return '非常强烈'
  return '未知'
}

/**
 * 计算平均强度
 */
export function calculateAverageIntensity(feelings: FeelingItem[]): number {
  if (feelings.length === 0) return 0
  const sum = feelings.reduce((acc, f) => acc + f.intensity, 0)
  return Math.round((sum / feelings.length) * 10) / 10 // 保留一位小数
}

/**
 * 获取最高强度
 */
export function getMaxIntensity(feelings: FeelingItem[]): number {
  if (feelings.length === 0) return 0
  return Math.max(...feelings.map(f => f.intensity))
}

/**
 * 根据情绪 ID 列表获取 Top N 情绪
 */
export function getTopMoods(moodIds: string[], topN: number = 3): string[] {
  // 统计每个情绪出现的次数
  const moodCount = moodIds.reduce((acc, id) => {
    acc[id] = (acc[id] || 0) + 1
    return acc
  }, {} as Record<string, number>)

  // 按出现次数排序
  const sorted = Object.entries(moodCount)
    .sort((a, b) => b[1] - a[1])
    .map(([id]) => id)

  return sorted.slice(0, topN)
}

/**
 * 从 FeelingItem 列表中提取情绪 ID
 */
export function extractMoodIds(feelings: FeelingItem[]): string[] {
  return feelings.map(f => f.emotion)
}

/**
 * 判断是否是积极情绪
 */
export function isPositiveMood(moodId: string): boolean {
  const positiveMoods = [
    'high_pleasure',
    'happy',
    'excited',
    'grateful',
    'calm',
    'peaceful',
    'relaxed',
    'focus',
    'energized'
  ]
  return positiveMoods.includes(moodId)
}

/**
 * 判断是否是消极情绪
 */
export function isNegativeMood(moodId: string): boolean {
  const negativeMoods = [
    'sad',
    'lonely',
    'disappointed',
    'angry',
    'frustrated',
    'annoyed',
    'fear',
    'scared',
    'low_anxiety',
    'worried',
    'nervous'
  ]
  return negativeMoods.includes(moodId)
}

/**
 * 获取所有可用的情绪选项
 */
export function getAllMoodOptions(): Mood[] {
  return EMOTIONS
}

/**
 * 搜索情绪（根据标签）
 */
export function searchMoods(query: string): Mood[] {
  const lowerQuery = query.toLowerCase()
  return EMOTIONS.filter(emotion =>
    emotion.label.toLowerCase().includes(lowerQuery)
  )
}
