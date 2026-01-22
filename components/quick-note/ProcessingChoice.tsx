/**
 * 处理方式选择组件
 * 三段式选择：仅记录 / 添加情绪 / NVC 分析
 */

import React from 'react'
import { FileText, Heart, Sparkles } from 'lucide-react'
import { Modal } from '../common/Modal'
import { ProcessingMode } from '../../models'

interface ProcessingChoiceProps {
  isOpen: boolean
  onClose: () => void
  onSelect: (mode: ProcessingMode) => void
  transcription: string
}

export const ProcessingChoice: React.FC<ProcessingChoiceProps> = ({
  isOpen,
  onClose,
  onSelect,
  transcription
}) => {
  const handleSelect = (mode: ProcessingMode) => {
    onSelect(mode)
    onClose()
  }

  const options = [
    {
      mode: ProcessingMode.ONLY_RECORD,
      icon: FileText,
      title: '仅记录',
      description: '保存转写文本，不做额外处理',
      color: 'text-stone-600',
      bgColor: 'bg-stone-50 hover:bg-stone-100',
      borderColor: 'border-stone-200'
    },
    {
      mode: ProcessingMode.WITH_MOOD,
      icon: Heart,
      title: '添加情绪',
      description: '标记情绪标签和强度',
      color: 'text-terracotta',
      bgColor: 'bg-terracotta/10 hover:bg-terracotta/20',
      borderColor: 'border-terracotta/30'
    },
    {
      mode: ProcessingMode.WITH_NVC,
      icon: Sparkles,
      title: 'NVC 分析',
      description: 'AI 提取观察、感受、需要、行动建议',
      color: 'text-primary',
      bgColor: 'bg-primary/10 hover:bg-primary/20',
      borderColor: 'border-primary/30'
    }
  ]

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="如何处理这条记录？"
      size="md"
    >
      {/* 转写预览 */}
      <div className="mb-6 p-4 bg-stone-50 rounded-lg">
        <p className="text-sm text-text-light mb-1">转写内容：</p>
        <p className="text-base text-text-main line-clamp-3">
          {transcription}
        </p>
      </div>

      {/* 选项列表 */}
      <div className="space-y-3">
        {options.map((option) => {
          const Icon = option.icon
          return (
            <button
              key={option.mode}
              onClick={() => handleSelect(option.mode)}
              className={`
                w-full p-4 rounded-xl border-2
                ${option.bgColor} ${option.borderColor}
                transition-all duration-200
                hover:scale-[1.02] hover:shadow-md
                active:scale-[0.98]
                flex items-start gap-4
              `}
            >
              {/* 图标 */}
              <div className={`
                flex-shrink-0 w-12 h-12 rounded-full
                flex items-center justify-center
                ${option.bgColor}
              `}>
                <Icon className={`w-6 h-6 ${option.color}`} />
              </div>

              {/* 文字 */}
              <div className="flex-1 text-left">
                <h3 className={`text-lg font-semibold ${option.color} mb-1`}>
                  {option.title}
                </h3>
                <p className="text-sm text-text-light">
                  {option.description}
                </p>
              </div>

              {/* 推荐标签 */}
              {option.mode === ProcessingMode.ONLY_RECORD && (
                <span className="flex-shrink-0 px-2 py-1 bg-stone-200 text-stone-600 text-xs rounded-full">
                  默认
                </span>
              )}
            </button>
          )
        })}
      </div>

      {/* 提示 */}
      <p className="mt-4 text-xs text-text-light text-center">
        选择后可在详情页随时修改
      </p>
    </Modal>
  )
}
