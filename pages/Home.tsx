import React, { useState, useCallback } from 'react'
import { User, Sparkles } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { RecordButton } from '../components/audio/RecordButton'
import { ProcessingChoice } from '../components/quick-note/ProcessingChoice'
import { LoadingSpinner } from '../components/common/LoadingSpinner'
import { useQuickNote } from '../hooks/useQuickNote'
import { ProcessingMode } from '../models'

export const Home: React.FC = () => {
  const navigate = useNavigate()
  const {
    currentQuickNote,
    isProcessing,
    processingStage,
    createFromAudio,
    changeMode
  } = useQuickNote()

  const [showProcessingChoice, setShowProcessingChoice] = useState(false)
  const [currentAudioBlob, setCurrentAudioBlob] = useState<Blob | null>(null)
  const [currentTranscription, setCurrentTranscription] = useState('')

  // 录音完成处理
  const handleRecordComplete = useCallback(async (audioBlob: Blob) => {
    try {
      setCurrentAudioBlob(audioBlob)

      // 创建碎片记录（默认仅记录模式）
      const note = await createFromAudio(audioBlob, ProcessingMode.ONLY_RECORD)

      if (note) {
        setCurrentTranscription(note.transcription)
        // 显示处理方式选择弹窗
        setShowProcessingChoice(true)
      }
    } catch (error) {
      console.error('Failed to create quick note:', error)
      alert('录音处理失败，请重试')
    }
  }, [createFromAudio])

  // 选择处理模式
  const handleModeSelect = useCallback(async (mode: ProcessingMode) => {
    if (!currentQuickNote) return

    try {
      // 如果选择的不是默认模式，更新处理模式
      if (mode !== ProcessingMode.ONLY_RECORD) {
        await changeMode(currentQuickNote.id, mode)
      }

      // 导航到记录列表或详情页
      navigate('/records')
    } catch (error) {
      console.error('Failed to change mode:', error)
      alert('处理模式切换失败')
    }
  }, [currentQuickNote, changeMode, navigate])

  // 获取处理状态文案
  const getProcessingText = (): string => {
    switch (processingStage) {
      case 'transcribing':
        return '语音转文字中...'
      case 'analyzing':
        return 'AI 分析中...'
      case 'saving':
        return '保存中...'
      default:
        return '处理中...'
    }
  }

  // 获取当前时间和问候语
  const getGreeting = (): { date: string; greeting: string } => {
    const now = new Date()
    const hour = now.getHours()
    const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    const month = now.getMonth() + 1
    const day = now.getDate()
    const weekDay = weekDays[now.getDay()]

    let greeting = '早上好'
    if (hour >= 12 && hour < 14) {
      greeting = '中午好'
    } else if (hour >= 14 && hour < 18) {
      greeting = '下午好'
    } else if (hour >= 18) {
      greeting = '晚上好'
    }

    return {
      date: `${month}月${day}日 ${weekDay}`,
      greeting
    }
  }

  const { date, greeting } = getGreeting()

  return (
    <div className="flex-1 flex flex-col w-full relative overflow-hidden bg-background-light h-full">
      {/* Header */}
      <header className="flex items-center justify-between px-6 pt-12 pb-2 w-full z-20 flex-none">
        <div className="flex flex-col gap-1">
          <span className="text-xs font-medium text-gray-400 tracking-wide">
            {date}
          </span>
          <h2 className="text-3xl font-bold leading-tight tracking-tight text-primary">
            {greeting}
          </h2>
        </div>
        <button
          className="w-10 h-10 flex items-center justify-center rounded-full bg-white shadow-sm border border-gray-100 text-primary transition-transform active:scale-95 hover:bg-gray-50"
          onClick={() => {/* TODO: Open Profile */}}
        >
          <User size={20} />
        </button>
      </header>

      {/* Background Ambient Light */}
      <div aria-hidden="true" className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
        <div className="absolute top-[15%] left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-gradient-to-b from-[#E6EBF0]/60 to-transparent rounded-full blur-3xl opacity-60"></div>
      </div>

      {/* Center Text */}
      <section className="flex-1 flex flex-col justify-center items-center px-8 z-10 pb-32">
        <div className="flex flex-col items-center gap-6 text-center select-none">
          <p className="text-base text-primary/30 font-medium transform scale-90 blur-[0.5px] transition-all duration-700">
            接纳所有情绪
          </p>
          <p className="text-lg text-primary/50 font-medium transform scale-95 transition-all duration-700">
            让感受自由流动
          </p>
          <p className="text-2xl text-primary/70 font-medium transition-all duration-700">
            允许一切发生
          </p>
          <p className="text-3xl md:text-4xl text-primary font-bold tracking-tight transition-all duration-700 drop-shadow-sm mt-3">
            先看见，再思考
          </p>
        </div>
      </section>

      {/* Bottom Actions */}
      <section className="absolute bottom-0 left-0 w-full flex flex-col items-center justify-end pb-24 z-20 bg-gradient-to-t from-background-light via-background-light/90 to-transparent pt-16">
        {/* 开启洞察按钮 */}
        <button
          onClick={() => navigate('/insights')}
          className="mb-8 group flex items-center gap-2.5 pl-3 pr-4 py-2.5 rounded-full bg-white border border-gray-200 shadow-sm hover:shadow-md hover:border-primary/30 transition-all cursor-pointer active:scale-95"
        >
          <div className="relative w-5 h-5 flex items-center justify-center">
            <Sparkles size={18} className="text-yellow-500 fill-yellow-500 animate-pulse-slow" />
          </div>
          <span className="text-sm font-semibold text-primary">查看洞察</span>
        </button>

        {/* 处理中提示 */}
        {isProcessing && (
          <div className="mb-8">
            <LoadingSpinner text={getProcessingText()} />
          </div>
        )}

        {/* 录音按钮 */}
        {!isProcessing && (
          <RecordButton
            mode="press"
            onRecordComplete={handleRecordComplete}
          />
        )}
      </section>

      {/* 处理方式选择弹窗 */}
      <ProcessingChoice
        isOpen={showProcessingChoice}
        onClose={() => setShowProcessingChoice(false)}
        onSelect={handleModeSelect}
        transcription={currentTranscription}
      />
    </div>
  )
}
