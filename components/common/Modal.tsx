/**
 * 通用模态框组件
 */

import React, { useEffect } from 'react'
import { X } from 'lucide-react'

interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  children: React.ReactNode
  size?: 'sm' | 'md' | 'lg'
  showCloseButton?: boolean
}

export const Modal: React.FC<ModalProps> = ({
  isOpen,
  onClose,
  title,
  children,
  size = 'md',
  showCloseButton = true
}) => {
  // ESC 键关闭
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }

    if (isOpen) {
      document.addEventListener('keydown', handleEsc)
      // 禁止背景滚动
      document.body.style.overflow = 'hidden'
    }

    return () => {
      document.removeEventListener('keydown', handleEsc)
      document.body.style.overflow = 'unset'
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  const sizeClasses = {
    sm: 'max-w-sm',
    md: 'max-w-md',
    lg: 'max-w-lg'
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      {/* 背景遮罩 */}
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" />

      {/* 模态框内容 */}
      <div
        className={`
          relative bg-surface-light rounded-2xl shadow-2xl
          w-full ${sizeClasses[size]}
          max-h-[90vh] overflow-y-auto
          animate-in fade-in zoom-in-95 duration-200
        `}
        onClick={(e) => e.stopPropagation()}
      >
        {/* 头部 */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between p-6 pb-4">
            {title && (
              <h2 className="text-xl font-semibold text-text-main">
                {title}
              </h2>
            )}
            {showCloseButton && (
              <button
                onClick={onClose}
                className="p-2 hover:bg-stone-100 rounded-full transition-colors"
                aria-label="关闭"
              >
                <X className="w-5 h-5 text-text-light" />
              </button>
            )}
          </div>
        )}

        {/* 内容 */}
        <div className="p-6 pt-2">
          {children}
        </div>
      </div>
    </div>
  )
}
