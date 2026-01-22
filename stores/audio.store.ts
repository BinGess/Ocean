/**
 * 音频录制状态管理
 */

import { create } from 'zustand'
import { audioService } from '../services/audio.service'

interface AudioState {
  // 状态
  isRecording: boolean
  recordingDuration: number        // 秒
  audioBlob: Blob | null
  error: string | null

  // 定时器 ID
  timerInterval: number | null

  // 操作
  startRecording: () => Promise<void>
  stopRecording: () => Promise<Blob>
  cancelRecording: () => void
  reset: () => void
}

export const useAudioStore = create<AudioState>((set, get) => ({
  // 初始状态
  isRecording: false,
  recordingDuration: 0,
  audioBlob: null,
  error: null,
  timerInterval: null,

  // 开始录音
  startRecording: async () => {
    try {
      set({ error: null })

      await audioService.startRecording()
      set({ isRecording: true, recordingDuration: 0 })

      // 启动计时器
      const intervalId = window.setInterval(() => {
        set(state => ({
          recordingDuration: state.recordingDuration + 1
        }))
      }, 1000)

      set({ timerInterval: intervalId })

      console.log('🎤 Recording started')
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '录音启动失败'
      set({ error: errorMessage, isRecording: false })
      console.error('❌ Failed to start recording:', error)
      throw error
    }
  },

  // 停止录音
  stopRecording: async () => {
    try {
      const blob = await audioService.stopRecording()
      const { timerInterval } = get()

      // 清除计时器
      if (timerInterval !== null) {
        window.clearInterval(timerInterval)
      }

      set({
        isRecording: false,
        audioBlob: blob,
        timerInterval: null
      })

      console.log('🎤 Recording stopped')
      return blob
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '录音停止失败'
      set({ error: errorMessage, isRecording: false })
      console.error('❌ Failed to stop recording:', error)
      throw error
    }
  },

  // 取消录音
  cancelRecording: () => {
    audioService.cancelRecording()
    const { timerInterval } = get()

    if (timerInterval !== null) {
      window.clearInterval(timerInterval)
    }

    set({
      isRecording: false,
      recordingDuration: 0,
      audioBlob: null,
      timerInterval: null,
      error: null
    })

    console.log('🎤 Recording cancelled')
  },

  // 重置状态
  reset: () => {
    const { timerInterval } = get()

    if (timerInterval !== null) {
      window.clearInterval(timerInterval)
    }

    set({
      isRecording: false,
      recordingDuration: 0,
      audioBlob: null,
      timerInterval: null,
      error: null
    })
  }
}))
