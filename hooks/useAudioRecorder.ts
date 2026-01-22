/**
 * 音频录制 Hook
 * 封装录音逻辑，提供便捷的录音控制
 */

import { useCallback, useEffect } from 'react'
import { useAudioStore } from '../stores/audio.store'
import { useRecordStore } from '../stores/record.store'
import { ProcessingMode } from '../models'

export interface UseAudioRecorderOptions {
  onRecordingComplete?: (audioBlob: Blob) => void
  onError?: (error: string) => void
  maxDuration?: number  // 最大录音时长（秒）
}

export function useAudioRecorder(options?: UseAudioRecorderOptions) {
  const {
    isRecording,
    recordingDuration,
    audioBlob,
    error,
    startRecording,
    stopRecording,
    cancelRecording,
    reset
  } = useAudioStore()

  const { createQuickNoteFromAudio } = useRecordStore()

  // 监听最大时长
  useEffect(() => {
    if (options?.maxDuration && recordingDuration >= options.maxDuration) {
      handleStopRecording()
    }
  }, [recordingDuration, options?.maxDuration])

  // 监听错误
  useEffect(() => {
    if (error && options?.onError) {
      options.onError(error)
    }
  }, [error, options?.onError])

  // 开始录音
  const handleStartRecording = useCallback(async () => {
    try {
      await startRecording()
    } catch (error) {
      console.error('Failed to start recording:', error)
    }
  }, [startRecording])

  // 停止录音
  const handleStopRecording = useCallback(async () => {
    try {
      const blob = await stopRecording()
      if (options?.onRecordingComplete) {
        options.onRecordingComplete(blob)
      }
      return blob
    } catch (error) {
      console.error('Failed to stop recording:', error)
      return null
    }
  }, [stopRecording, options?.onRecordingComplete])

  // 取消录音
  const handleCancelRecording = useCallback(() => {
    cancelRecording()
  }, [cancelRecording])

  // 长按开始，释放停止
  const handlePressStart = useCallback((event: React.PointerEvent) => {
    event.preventDefault()
    handleStartRecording()
  }, [handleStartRecording])

  const handlePressEnd = useCallback(async (event: React.PointerEvent) => {
    event.preventDefault()
    if (isRecording) {
      await handleStopRecording()
    }
  }, [isRecording, handleStopRecording])

  // 创建记录（快捷方法）
  const createQuickNote = useCallback(async (
    blob: Blob,
    mode: ProcessingMode = ProcessingMode.ONLY_RECORD
  ) => {
    try {
      const quickNote = await createQuickNoteFromAudio(blob, mode)
      reset() // 重置录音状态
      return quickNote
    } catch (error) {
      console.error('Failed to create quick note:', error)
      throw error
    }
  }, [createQuickNoteFromAudio, reset])

  return {
    // 状态
    isRecording,
    recordingDuration,
    audioBlob,
    error,

    // 操作方法
    startRecording: handleStartRecording,
    stopRecording: handleStopRecording,
    cancelRecording: handleCancelRecording,
    reset,

    // 长按事件处理
    handlePressStart,
    handlePressEnd,

    // 快捷方法
    createQuickNote
  }
}
