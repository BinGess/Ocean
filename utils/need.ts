/**
 * 需要相关工具函数
 */

import { Need } from '../models'
import { NEEDS, getNeedById, getRelatedNeedsByEmotion } from '../config/needs'

/**
 * 获取需要的标签
 */
export function getNeedLabel(needId: string): string {
  const need = getNeedById(needId)
  return need?.label || '未知需要'
}

/**
 * 获取多个需要的标签（用逗号分隔）
 */
export function getNeedLabels(needIds: string[]): string {
  return needIds.map(id => getNeedLabel(id)).join('、')
}

/**
 * 根据需要 ID 列表获取 Top N 需要
 */
export function getTopNeeds(needIds: string[], topN: number = 3): string[] {
  // 统计每个需要出现的次数
  const needCount = needIds.reduce((acc, id) => {
    acc[id] = (acc[id] || 0) + 1
    return acc
  }, {} as Record<string, number>)

  // 按出现次数排序
  const sorted = Object.entries(needCount)
    .sort((a, b) => b[1] - a[1])
    .map(([id]) => id)

  return sorted.slice(0, topN)
}

/**
 * 根据情绪推荐需要
 * @param emotionIds 情绪 ID 列表
 * @returns 推荐的需要列表（去重）
 */
export function recommendNeedsByEmotions(emotionIds: string[]): Need[] {
  const recommendedNeeds = new Map<string, Need>()

  emotionIds.forEach(emotionId => {
    const related = getRelatedNeedsByEmotion(emotionId)
    related.forEach(need => {
      recommendedNeeds.set(need.id, need)
    })
  })

  return Array.from(recommendedNeeds.values())
}

/**
 * 获取所有可用的需要选项
 */
export function getAllNeedOptions(): Need[] {
  return NEEDS
}

/**
 * 搜索需要（根据标签或描述）
 */
export function searchNeeds(query: string): Need[] {
  const lowerQuery = query.toLowerCase()
  return NEEDS.filter(need =>
    need.label.toLowerCase().includes(lowerQuery) ||
    need.description?.toLowerCase().includes(lowerQuery)
  )
}

/**
 * 获取需要的描述
 */
export function getNeedDescription(needId: string): string {
  const need = getNeedById(needId)
  return need?.description || ''
}

/**
 * 验证需要 ID 是否有效
 */
export function isValidNeedId(needId: string): boolean {
  return NEEDS.some(need => need.id === needId)
}

/**
 * 批量验证需要 ID
 */
export function validateNeedIds(needIds: string[]): string[] {
  return needIds.filter(id => isValidNeedId(id))
}
