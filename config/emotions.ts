/**
 * 情绪词库配置
 * 基于现有的 Mood 定义，并扩展更多情绪词
 */

import { Mood, MoodCategory } from '../models/mood.model'

/**
 * 情绪词库
 */
export const EMOTIONS: Mood[] = [
  // 愉悦类
  {
    id: 'high_pleasure',
    label: '愉悦高涨',
    category: MoodCategory.HIGH_PLEASURE,
    color: {
      bg: 'bg-sage/20',
      text: 'text-[#4a5746]',
      dot: 'bg-sage'
    }
  },
  {
    id: 'happy',
    label: '开心',
    category: MoodCategory.HAPPY,
    color: {
      bg: 'bg-yellow-50',
      text: 'text-yellow-700',
      dot: 'bg-yellow-400'
    }
  },
  {
    id: 'excited',
    label: '兴奋',
    category: MoodCategory.HAPPY,
    color: {
      bg: 'bg-orange-50',
      text: 'text-orange-700',
      dot: 'bg-orange-400'
    }
  },
  {
    id: 'grateful',
    label: '感激',
    category: MoodCategory.HAPPY,
    color: {
      bg: 'bg-green-50',
      text: 'text-green-700',
      dot: 'bg-green-400'
    }
  },

  // 焦虑类
  {
    id: 'low_anxiety',
    label: '轻微焦虑',
    category: MoodCategory.LOW_ANXIETY,
    color: {
      bg: 'bg-terracotta/20',
      text: 'text-[#5c3a31]',
      dot: 'bg-terracotta'
    }
  },
  {
    id: 'worried',
    label: '担心',
    category: MoodCategory.LOW_ANXIETY,
    color: {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      dot: 'bg-amber-400'
    }
  },
  {
    id: 'nervous',
    label: '紧张',
    category: MoodCategory.LOW_ANXIETY,
    color: {
      bg: 'bg-red-50',
      text: 'text-red-700',
      dot: 'bg-red-400'
    }
  },

  // 平静类
  {
    id: 'calm',
    label: '平静',
    category: MoodCategory.CALM,
    color: {
      bg: 'bg-stone-100',
      text: 'text-stone-600',
      dot: 'bg-stone-400'
    }
  },
  {
    id: 'peaceful',
    label: '宁静',
    category: MoodCategory.CALM,
    color: {
      bg: 'bg-blue-50',
      text: 'text-blue-600',
      dot: 'bg-blue-300'
    }
  },
  {
    id: 'relaxed',
    label: '放松',
    category: MoodCategory.CALM,
    color: {
      bg: 'bg-teal-50',
      text: 'text-teal-600',
      dot: 'bg-teal-300'
    }
  },

  // 专注类
  {
    id: 'focus',
    label: '专注',
    category: MoodCategory.FOCUS,
    color: {
      bg: 'bg-primary/10',
      text: 'text-primary',
      dot: 'bg-primary'
    }
  },
  {
    id: 'energized',
    label: '充满活力',
    category: MoodCategory.FOCUS,
    color: {
      bg: 'bg-purple-50',
      text: 'text-purple-600',
      dot: 'bg-purple-400'
    }
  },

  // 不确定类
  {
    id: 'uncertainty',
    label: '不确定',
    category: MoodCategory.UNCERTAINTY,
    color: {
      bg: 'bg-gray-100',
      text: 'text-gray-600',
      dot: 'bg-gray-400'
    }
  },
  {
    id: 'confused',
    label: '困惑',
    category: MoodCategory.UNCERTAINTY,
    color: {
      bg: 'bg-slate-100',
      text: 'text-slate-600',
      dot: 'bg-slate-400'
    }
  },

  // 悲伤类
  {
    id: 'sad',
    label: '悲伤',
    category: MoodCategory.SAD,
    color: {
      bg: 'bg-indigo-50',
      text: 'text-indigo-700',
      dot: 'bg-indigo-400'
    }
  },
  {
    id: 'lonely',
    label: '孤独',
    category: MoodCategory.SAD,
    color: {
      bg: 'bg-gray-200',
      text: 'text-gray-700',
      dot: 'bg-gray-500'
    }
  },
  {
    id: 'disappointed',
    label: '失望',
    category: MoodCategory.SAD,
    color: {
      bg: 'bg-slate-200',
      text: 'text-slate-700',
      dot: 'bg-slate-500'
    }
  },

  // 愤怒类
  {
    id: 'angry',
    label: '愤怒',
    category: MoodCategory.ANGRY,
    color: {
      bg: 'bg-red-100',
      text: 'text-red-800',
      dot: 'bg-red-600'
    }
  },
  {
    id: 'frustrated',
    label: '沮丧',
    category: MoodCategory.ANGRY,
    color: {
      bg: 'bg-orange-100',
      text: 'text-orange-800',
      dot: 'bg-orange-600'
    }
  },
  {
    id: 'annoyed',
    label: '烦躁',
    category: MoodCategory.ANGRY,
    color: {
      bg: 'bg-rose-100',
      text: 'text-rose-800',
      dot: 'bg-rose-600'
    }
  },

  // 恐惧类
  {
    id: 'fear',
    label: '恐惧',
    category: MoodCategory.FEAR,
    color: {
      bg: 'bg-violet-50',
      text: 'text-violet-700',
      dot: 'bg-violet-400'
    }
  },
  {
    id: 'scared',
    label: '害怕',
    category: MoodCategory.FEAR,
    color: {
      bg: 'bg-purple-100',
      text: 'text-purple-700',
      dot: 'bg-purple-500'
    }
  },

  // 疲惫类
  {
    id: 'tired',
    label: '疲惫',
    category: MoodCategory.TIRED,
    color: {
      bg: 'bg-gray-100',
      text: 'text-gray-600',
      dot: 'bg-gray-400'
    }
  },
  {
    id: 'exhausted',
    label: '精疲力竭',
    category: MoodCategory.TIRED,
    color: {
      bg: 'bg-stone-200',
      text: 'text-stone-700',
      dot: 'bg-stone-500'
    }
  },
  {
    id: 'bored',
    label: '无聊',
    category: MoodCategory.TIRED,
    color: {
      bg: 'bg-neutral-100',
      text: 'text-neutral-600',
      dot: 'bg-neutral-400'
    }
  }
]

/**
 * 根据 ID 获取情绪
 */
export function getEmotionById(id: string): Mood | undefined {
  return EMOTIONS.find(emotion => emotion.id === id)
}

/**
 * 根据分类获取情绪列表
 */
export function getEmotionsByCategory(category: MoodCategory): Mood[] {
  return EMOTIONS.filter(emotion => emotion.category === category)
}

/**
 * 获取所有情绪分类
 */
export function getAllCategories(): MoodCategory[] {
  return Object.values(MoodCategory)
}
