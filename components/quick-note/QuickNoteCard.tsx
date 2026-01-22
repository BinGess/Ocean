/**
 * 碎片记录卡片组件
 */

import React from 'react'
import { Clock, Mic } from 'lucide-react'
import { QuickNote, ProcessingMode } from '../../models'
import { formatDistanceToNow } from '../../utils/date'

interface QuickNoteCardProps {
  note: QuickNote
  onClick?: () => void
  showDetail?: boolean
}

export const QuickNoteCard: React.FC<QuickNoteCardProps> = ({
  note,
  onClick,
  showDetail = false
}) => {
  // 格式化时长
  const formatDuration = (seconds?: number): string => {
    if (!seconds) return ''
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  // 获取处理模式标签
  const getModeLabel = (mode?: ProcessingMode): { text: string; color: string } => {
    switch (mode) {
      case ProcessingMode.WITH_NVC:
        return { text: 'NVC', color: 'bg-primary/10 text-primary' }
      case ProcessingMode.WITH_MOOD:
        return { text: '情绪', color: 'bg-terracotta/10 text-terracotta' }
      case ProcessingMode.ONLY_RECORD:
      default:
        return { text: '记录', color: 'bg-stone-100 text-stone-600' }
    }
  }

  const modeLabel = getModeLabel(note.processingMode)

  return (
    <div
      className={`
        p-4 bg-surface-light rounded-xl border border-stone-200
        transition-all duration-200
        ${onClick ? 'cursor-pointer hover:shadow-md hover:border-primary/30' : ''}
      `}
      onClick={onClick}
    >
      {/* 头部：时间 + 时长 */}
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2 text-xs text-text-light">
          <Clock className="w-3.5 h-3.5" />
          <span>{formatDistanceToNow(new Date(note.createdAt))}</span>
        </div>

        <div className="flex items-center gap-2">
          {/* 音频时长 */}
          {note.duration && (
            <div className="flex items-center gap-1 text-xs text-text-light">
              <Mic className="w-3.5 h-3.5" />
              <span>{formatDuration(note.duration)}</span>
            </div>
          )}

          {/* 处理模式标签 */}
          <span className={`px-2 py-0.5 rounded-full text-xs ${modeLabel.color}`}>
            {modeLabel.text}
          </span>
        </div>
      </div>

      {/* 转写文本 */}
      <p className={`text-base text-text-main ${showDetail ? '' : 'line-clamp-2'}`}>
        {note.transcription}
      </p>

      {/* 情绪标签（如果有） */}
      {note.moods && note.moods.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2">
          {note.moods.slice(0, 3).map((mood, idx) => (
            <span
              key={idx}
              className="px-2 py-1 bg-sage/20 text-sage text-xs rounded-full"
            >
              {mood}
            </span>
          ))}
          {note.moods.length > 3 && (
            <span className="px-2 py-1 bg-stone-100 text-stone-600 text-xs rounded-full">
              +{note.moods.length - 3}
            </span>
          )}
        </div>
      )}

      {/* NVC 摘要（如果有） */}
      {note.nvc && showDetail && (
        <div className="mt-3 p-3 bg-primary/5 rounded-lg space-y-2">
          <div>
            <span className="text-xs font-medium text-primary">观察：</span>
            <p className="text-sm text-text-main">{note.nvc.observation}</p>
          </div>
          {note.nvc.feelings && note.nvc.feelings.length > 0 && (
            <div>
              <span className="text-xs font-medium text-primary">感受：</span>
              <div className="flex flex-wrap gap-1 mt-1">
                {note.nvc.feelings.map((f, idx) => (
                  <span
                    key={idx}
                    className="px-2 py-0.5 bg-white text-xs rounded-full border border-primary/20"
                  >
                    {f.emotion} ({f.intensity}/5)
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
