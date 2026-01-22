/**
 * 主录音按钮组件
 * 支持长按录音、点击录音
 */

import React, { useState, useRef, useCallback } from 'react'
import { Mic, Square } from 'lucide-react'
import { useAudioRecorder } from '../../hooks/useAudioRecorder'

interface RecordButtonProps {
  onRecordComplete?: (audioBlob: Blob) => void
  mode?: 'press' | 'click' // 长按模式 or 点击模式
  className?: string
}

export const RecordButton: React.FC<RecordButtonProps> = ({
  onRecordComplete,
  mode = 'press',
  className = ''
}) => {
  const {
    isRecording,
    recordingDuration,
    startRecording,
    stopRecording,
    audioBlob
  } = useAudioRecorder()

  const [isPressing, setIsPressing] = useState(false)
  const pressTimerRef = useRef<NodeJS.Timeout | null>(null)
  const longPressThreshold = 200 // 200ms 判定为长按

  // 长按开始
  const handlePressStart = useCallback(async () => {
    setIsPressing(true)

    if (mode === 'press') {
      // 长按模式：延迟开始录音（防止误触）
      pressTimerRef.current = setTimeout(async () => {
        await startRecording()
      }, longPressThreshold)
    }
  }, [mode, startRecording])

  // 长按结束
  const handlePressEnd = useCallback(async () => {
    setIsPressing(false)

    if (pressTimerRef.current) {
      clearTimeout(pressTimerRef.current)
      pressTimerRef.current = null
    }

    if (isRecording) {
      const blob = await stopRecording()
      if (blob && onRecordComplete) {
        onRecordComplete(blob)
      }
    }
  }, [isRecording, stopRecording, onRecordComplete])

  // 点击模式切换
  const handleClick = useCallback(async () => {
    if (mode === 'click') {
      if (isRecording) {
        const blob = await stopRecording()
        if (blob && onRecordComplete) {
          onRecordComplete(blob)
        }
      } else {
        await startRecording()
      }
    }
  }, [mode, isRecording, startRecording, stopRecording, onRecordComplete])

  // 格式化时长
  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  return (
    <div className={`flex flex-col items-center gap-4 ${className}`}>
      {/* 录音按钮 */}
      <button
        className={`
          relative w-24 h-24 rounded-full
          flex items-center justify-center
          transition-all duration-200
          shadow-lg
          ${isRecording
            ? 'bg-red-500 scale-110 animate-pulse'
            : isPressing
            ? 'bg-primary-dark scale-105'
            : 'bg-primary hover:bg-primary-dark'
          }
        `}
        onPointerDown={mode === 'press' ? handlePressStart : undefined}
        onPointerUp={mode === 'press' ? handlePressEnd : undefined}
        onPointerLeave={mode === 'press' ? handlePressEnd : undefined}
        onClick={mode === 'click' ? handleClick : undefined}
        aria-label={isRecording ? '停止录音' : '开始录音'}
      >
        {isRecording ? (
          <Square className="w-10 h-10 text-white" fill="white" />
        ) : (
          <Mic className="w-10 h-10 text-white" />
        )}

        {/* 录音波纹效果 */}
        {isRecording && (
          <>
            <span className="absolute inset-0 rounded-full bg-red-500 animate-ping opacity-75" />
            <span className="absolute inset-0 rounded-full bg-red-400 animate-ping opacity-50" style={{ animationDelay: '0.3s' }} />
          </>
        )}
      </button>

      {/* 提示文本 */}
      <div className="text-center">
        {isRecording ? (
          <div className="flex flex-col items-center gap-1">
            <span className="text-2xl font-semibold text-red-500 font-mono">
              {formatDuration(recordingDuration)}
            </span>
            <span className="text-sm text-text-light">
              {mode === 'press' ? '松开结束' : '点击停止'}
            </span>
          </div>
        ) : (
          <span className="text-base text-text-light">
            {mode === 'press' ? '按住说话' : '点击开始'}
          </span>
        )}
      </div>

      {/* 录音提示 */}
      {!isRecording && (
        <p className="text-xs text-text-light text-center max-w-xs">
          {mode === 'press'
            ? '长按按钮即可录音，松手自动保存'
            : '点击按钮开始录音，再次点击停止'
          }
        </p>
      )}
    </div>
  )
}
