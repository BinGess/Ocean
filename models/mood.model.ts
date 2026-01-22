/**
 * 情绪模型
 */

export enum MoodCategory {
  HIGH_PLEASURE = 'high_pleasure',     // 愉悦高涨
  LOW_ANXIETY = 'low_anxiety',         // 轻微焦虑
  CALM = 'calm',                       // 平静
  FOCUS = 'focus',                     // 专注
  UNCERTAINTY = 'uncertainty',         // 不确定
  HAPPY = 'happy',                     // 开心
  SAD = 'sad',                         // 悲伤
  ANGRY = 'angry',                     // 愤怒
  FEAR = 'fear',                       // 恐惧
  TIRED = 'tired'                      // 疲惫
}

/**
 * 情绪接口
 */
export interface Mood {
  id: string                     // 唯一标识
  label: string                  // 显示名称（中文）
  category: MoodCategory         // 分类
  color: {
    bg: string                   // 背景色（Tailwind class）
    text: string                 // 文字色（Tailwind class）
    dot: string                  // 点标记色（Tailwind class）
  }
  intensity?: number             // 强度（1-5），可选
}

/**
 * 情绪颜色映射
 */
export interface MoodColorMap {
  [key: string]: {
    bg: string
    text: string
    dot: string
  }
}
