/**
 * 需要模型（基于 NVC 非暴力沟通）
 */

export enum NeedCategory {
  CONNECTION = 'connection',        // 连接
  AUTONOMY = 'autonomy',           // 自主
  MEANING = 'meaning',             // 意义
  SAFETY = 'safety',               // 安全
  REST = 'rest',                   // 休息
  GROWTH = 'growth',               // 成长
  PLAY = 'play'                    // 玩乐
}

/**
 * 需要接口
 */
export interface Need {
  id: string                     // 唯一标识
  label: string                  // 显示名称（中文）
  category: NeedCategory         // 分类
  description?: string           // 描述（可选）
  relatedEmotions?: string[]     // 相关情绪 ID（可选）
}
