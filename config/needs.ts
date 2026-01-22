/**
 * 需要词库配置
 * 基于 NVC（非暴力沟通）框架
 */

import { Need, NeedCategory } from '../models/need.model'

/**
 * 需要词库
 */
export const NEEDS: Need[] = [
  // 连接类（Connection）
  {
    id: 'connection',
    label: '连接',
    category: NeedCategory.CONNECTION,
    description: '与他人建立联系和关系的需要'
  },
  {
    id: 'understanding',
    label: '被理解',
    category: NeedCategory.CONNECTION,
    description: '被他人理解和看见的需要',
    relatedEmotions: ['lonely', 'sad', 'frustrated']
  },
  {
    id: 'acceptance',
    label: '接纳',
    category: NeedCategory.CONNECTION,
    description: '被他人接纳和认可的需要',
    relatedEmotions: ['uncertain', 'worried']
  },
  {
    id: 'belonging',
    label: '归属',
    category: NeedCategory.CONNECTION,
    description: '归属于某个群体的需要',
    relatedEmotions: ['lonely', 'sad']
  },
  {
    id: 'trust',
    label: '信任',
    category: NeedCategory.CONNECTION,
    description: '信任他人和被信任的需要',
    relatedEmotions: ['fear', 'worried']
  },
  {
    id: 'communication',
    label: '沟通',
    category: NeedCategory.CONNECTION,
    description: '有效沟通和表达的需要'
  },

  // 自主类（Autonomy）
  {
    id: 'autonomy',
    label: '自主',
    category: NeedCategory.AUTONOMY,
    description: '自己做决定和选择的需要',
    relatedEmotions: ['frustrated', 'angry', 'annoyed']
  },
  {
    id: 'freedom',
    label: '自由',
    category: NeedCategory.AUTONOMY,
    description: '自由行动和选择的需要',
    relatedEmotions: ['frustrated', 'trapped']
  },
  {
    id: 'control',
    label: '掌控',
    category: NeedCategory.AUTONOMY,
    description: '掌控自己生活和环境的需要',
    relatedEmotions: ['anxious', 'worried', 'uncertain']
  },
  {
    id: 'choice',
    label: '选择',
    category: NeedCategory.AUTONOMY,
    description: '有选择权的需要',
    relatedEmotions: ['frustrated', 'helpless']
  },
  {
    id: 'space',
    label: '空间',
    category: NeedCategory.AUTONOMY,
    description: '个人空间和边界的需要',
    relatedEmotions: ['overwhelmed', 'tired']
  },

  // 意义类（Meaning）
  {
    id: 'meaning',
    label: '意义',
    category: NeedCategory.MEANING,
    description: '生活有意义和目的的需要',
    relatedEmotions: ['empty', 'confused', 'lost']
  },
  {
    id: 'purpose',
    label: '目的',
    category: NeedCategory.MEANING,
    description: '有明确目标和方向的需要',
    relatedEmotions: ['confused', 'uncertain']
  },
  {
    id: 'contribution',
    label: '贡献',
    category: NeedCategory.MEANING,
    description: '对他人或社会有贡献的需要',
    relatedEmotions: ['empty', 'unfulfilled']
  },
  {
    id: 'achievement',
    label: '成就',
    category: NeedCategory.MEANING,
    description: '完成目标和取得成就的需要',
    relatedEmotions: ['disappointed', 'frustrated']
  },
  {
    id: 'creativity',
    label: '创造',
    category: NeedCategory.MEANING,
    description: '创造和表达的需要',
    relatedEmotions: ['bored', 'restless']
  },

  // 安全类（Safety）
  {
    id: 'safety',
    label: '安全',
    category: NeedCategory.SAFETY,
    description: '身心安全的需要',
    relatedEmotions: ['fear', 'scared', 'anxious']
  },
  {
    id: 'stability',
    label: '稳定',
    category: NeedCategory.SAFETY,
    description: '环境和生活稳定的需要',
    relatedEmotions: ['anxious', 'worried', 'uncertain']
  },
  {
    id: 'predictability',
    label: '可预测',
    category: NeedCategory.SAFETY,
    description: '能预测和掌握未来的需要',
    relatedEmotions: ['anxious', 'uncertain']
  },
  {
    id: 'order',
    label: '秩序',
    category: NeedCategory.SAFETY,
    description: '环境有序的需要',
    relatedEmotions: ['overwhelmed', 'stressed']
  },
  {
    id: 'protection',
    label: '保护',
    category: NeedCategory.SAFETY,
    description: '被保护和保护他人的需要',
    relatedEmotions: ['fear', 'vulnerable']
  },

  // 休息类（Rest）
  {
    id: 'rest',
    label: '休息',
    category: NeedCategory.REST,
    description: '身心休息的需要',
    relatedEmotions: ['tired', 'exhausted', 'overwhelmed']
  },
  {
    id: 'relaxation',
    label: '放松',
    category: NeedCategory.REST,
    description: '放松和舒缓的需要',
    relatedEmotions: ['stressed', 'tense', 'anxious']
  },
  {
    id: 'sleep',
    label: '睡眠',
    category: NeedCategory.REST,
    description: '充足睡眠的需要',
    relatedEmotions: ['tired', 'exhausted']
  },
  {
    id: 'peace',
    label: '宁静',
    category: NeedCategory.REST,
    description: '内心平静的需要',
    relatedEmotions: ['stressed', 'overwhelmed']
  },

  // 成长类（Growth）
  {
    id: 'growth',
    label: '成长',
    category: NeedCategory.GROWTH,
    description: '个人成长和发展的需要',
    relatedEmotions: ['stagnant', 'bored']
  },
  {
    id: 'learning',
    label: '学习',
    category: NeedCategory.GROWTH,
    description: '学习新事物的需要',
    relatedEmotions: ['curious', 'excited']
  },
  {
    id: 'challenge',
    label: '挑战',
    category: NeedCategory.GROWTH,
    description: '面对挑战和突破的需要',
    relatedEmotions: ['bored', 'restless']
  },
  {
    id: 'mastery',
    label: '精通',
    category: NeedCategory.GROWTH,
    description: '精通某项技能的需要',
    relatedEmotions: ['frustrated', 'impatient']
  },

  // 玩乐类（Play）
  {
    id: 'play',
    label: '玩乐',
    category: NeedCategory.PLAY,
    description: '玩乐和享受的需要',
    relatedEmotions: ['bored', 'serious', 'stressed']
  },
  {
    id: 'fun',
    label: '乐趣',
    category: NeedCategory.PLAY,
    description: '体验乐趣的需要',
    relatedEmotions: ['bored', 'dull']
  },
  {
    id: 'spontaneity',
    label: '自发',
    category: NeedCategory.PLAY,
    description: '自发和即兴的需要',
    relatedEmotions: ['rigid', 'controlled']
  },
  {
    id: 'humor',
    label: '幽默',
    category: NeedCategory.PLAY,
    description: '幽默和轻松的需要',
    relatedEmotions: ['serious', 'heavy']
  }
]

/**
 * 根据 ID 获取需要
 */
export function getNeedById(id: string): Need | undefined {
  return NEEDS.find(need => need.id === id)
}

/**
 * 根据分类获取需要列表
 */
export function getNeedsByCategory(category: NeedCategory): Need[] {
  return NEEDS.filter(need => need.category === category)
}

/**
 * 根据情绪 ID 推荐相关需要
 */
export function getRelatedNeedsByEmotion(emotionId: string): Need[] {
  return NEEDS.filter(need =>
    need.relatedEmotions?.includes(emotionId)
  )
}

/**
 * 获取所有需要分类
 */
export function getAllNeedCategories(): NeedCategory[] {
  return Object.values(NeedCategory)
}
