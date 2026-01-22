/**
 * 记录状态管理（碎片 + 日记）
 */

import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'
import { Record, QuickNote, Journal, ProcessingMode, RecordType } from '../models'
import { transcriptionService } from '../services/transcription.service'
import { aiAnalysisService } from '../services/ai-analysis.service'
import { createRecord, updateRecord, deleteRecord, getRecordById } from '../services/db/records.db'
import { v4 as uuidv4 } from 'uuid'

interface RecordState {
  // 当前正在处理的记录
  currentRecord: Record | null

  // 处理状态
  isProcessing: boolean
  processingStage: 'idle' | 'transcribing' | 'analyzing' | 'saving' | 'done'
  error: string | null

  // 操作方法：碎片记录
  createQuickNoteFromAudio: (audioBlob: Blob, mode: ProcessingMode) => Promise<QuickNote>
  updateQuickNoteMode: (id: string, mode: ProcessingMode) => Promise<void>

  // 操作方法：日记
  createJournal: (data: {
    transcription: string
    title?: string
    referencedFragments?: string[]
  }) => Promise<Journal>

  // 通用操作
  updateCurrentRecord: (updates: Partial<Record>) => Promise<void>
  deleteCurrentRecord: () => Promise<void>
  clearCurrent: () => void
  setError: (error: string) => void
}

export const useRecordStore = create<RecordState>()(
  immer((set, get) => ({
    // 初始状态
    currentRecord: null,
    isProcessing: false,
    processingStage: 'idle',
    error: null,

    // 创建碎片记录（从音频）
    createQuickNoteFromAudio: async (audioBlob: Blob, mode: ProcessingMode) => {
      try {
        set(state => {
          state.isProcessing = true
          state.processingStage = 'transcribing'
          state.error = null
        })

        // 1. 转写音频
        console.log('🔄 Transcribing audio...')
        const transcription = await transcriptionService.transcribe(audioBlob)

        // 2. 获取音频时长
        const duration = await audioService.getAudioDuration(audioBlob)

        // 3. 创建基础记录
        const quickNote: QuickNote = {
          id: uuidv4(),
          type: RecordType.QUICK_NOTE,
          transcription,
          duration,
          processingMode: mode,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          moods: [],
          needs: []
        }

        // 4. 如果是 NVC 模式，进行分析
        if (mode === ProcessingMode.WITH_NVC) {
          set(state => {
            state.processingStage = 'analyzing'
          })

          console.log('🔄 Analyzing with NVC...')
          const nvcResult = await aiAnalysisService.analyzeWithNVC(transcription)

          quickNote.nvc = {
            ...nvcResult,
            userConfirmed: false,
            userModified: false,
            generatedAt: new Date().toISOString()
          }

          // 提取情绪和需要 ID
          quickNote.moods = nvcResult.feelings.map(f => f.emotion)
          quickNote.needs = nvcResult.needs
        }

        // 5. 保存到数据库
        set(state => {
          state.processingStage = 'saving'
        })

        await createRecord(quickNote)

        // 6. 更新状态
        set(state => {
          state.currentRecord = quickNote
          state.isProcessing = false
          state.processingStage = 'done'
        })

        console.log('✅ Quick note created:', quickNote.id)
        return quickNote
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : '创建记录失败'
        set(state => {
          state.isProcessing = false
          state.processingStage = 'idle'
          state.error = errorMessage
        })
        console.error('❌ Failed to create quick note:', error)
        throw error
      }
    },

    // 更新碎片记录的处理模式
    updateQuickNoteMode: async (id: string, mode: ProcessingMode) => {
      try {
        set(state => {
          state.isProcessing = true
          state.processingStage = 'analyzing'
        })

        const record = await getRecordById(id)
        if (!record || record.type !== RecordType.QUICK_NOTE) {
          throw new Error('记录不存在或类型错误')
        }

        const updates: Partial<QuickNote> = {
          processingMode: mode
        }

        // 如果切换到 NVC 模式，进行分析
        if (mode === ProcessingMode.WITH_NVC && !record.nvc) {
          const nvcResult = await aiAnalysisService.analyzeWithNVC(record.transcription)
          updates.nvc = {
            ...nvcResult,
            userConfirmed: false,
            userModified: false,
            generatedAt: new Date().toISOString()
          }
          updates.moods = nvcResult.feelings.map(f => f.emotion)
          updates.needs = nvcResult.needs
        }

        // 如果切换到仅记录模式，清空情绪和需要
        if (mode === ProcessingMode.ONLY_RECORD) {
          updates.moods = []
          updates.needs = []
          updates.nvc = undefined
        }

        const updated = await updateRecord(id, updates)

        set(state => {
          state.currentRecord = updated
          state.isProcessing = false
          state.processingStage = 'done'
        })

        console.log('✅ Quick note mode updated:', id)
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : '更新失败'
        set(state => {
          state.isProcessing = false
          state.error = errorMessage
        })
        throw error
      }
    },

    // 创建日记
    createJournal: async (data) => {
      try {
        set(state => {
          state.isProcessing = true
          state.processingStage = 'saving'
        })

        const journal: Journal = {
          id: uuidv4(),
          type: RecordType.JOURNAL,
          transcription: data.transcription,
          title: data.title,
          date: new Date().toISOString().split('T')[0],
          referencedFragments: data.referencedFragments,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          moods: [],
          needs: []
        }

        await createRecord(journal)

        set(state => {
          state.currentRecord = journal
          state.isProcessing = false
          state.processingStage = 'done'
        })

        console.log('✅ Journal created:', journal.id)
        return journal
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : '创建日记失败'
        set(state => {
          state.isProcessing = false
          state.error = errorMessage
        })
        throw error
      }
    },

    // 更新当前记录
    updateCurrentRecord: async (updates) => {
      try {
        const { currentRecord } = get()
        if (!currentRecord) {
          throw new Error('没有当前记录')
        }

        const updated = await updateRecord(currentRecord.id, updates)

        set(state => {
          state.currentRecord = updated
        })

        console.log('✅ Record updated:', currentRecord.id)
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : '更新失败'
        set(state => {
          state.error = errorMessage
        })
        throw error
      }
    },

    // 删除当前记录
    deleteCurrentRecord: async () => {
      try {
        const { currentRecord } = get()
        if (!currentRecord) {
          throw new Error('没有当前记录')
        }

        await deleteRecord(currentRecord.id)

        set(state => {
          state.currentRecord = null
        })

        console.log('🗑️ Record deleted:', currentRecord.id)
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : '删除失败'
        set(state => {
          state.error = errorMessage
        })
        throw error
      }
    },

    // 清除当前记录
    clearCurrent: () => {
      set(state => {
        state.currentRecord = null
        state.isProcessing = false
        state.processingStage = 'idle'
        state.error = null
      })
    },

    // 设置错误
    setError: (error) => {
      set(state => {
        state.error = error
      })
    }
  }))
)

// 需要导入 audioService，但为了避免循环依赖，这里添加一个局部导入
import { audioService } from '../services/audio.service'
