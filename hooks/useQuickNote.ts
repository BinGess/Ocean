/**
 * 碎片记录 Hook
 * 管理碎片记录的创建、更新、删除
 */

import { useCallback } from 'react'
import { useRecordStore } from '../stores/record.store'
import { ProcessingMode, QuickNote } from '../models'

export function useQuickNote() {
  const {
    currentRecord,
    isProcessing,
    processingStage,
    error,
    createQuickNoteFromAudio,
    updateQuickNoteMode,
    updateCurrentRecord,
    deleteCurrentRecord,
    clearCurrent
  } = useRecordStore()

  // 创建碎片记录
  const createFromAudio = useCallback(async (
    audioBlob: Blob,
    mode: ProcessingMode = ProcessingMode.ONLY_RECORD
  ): Promise<QuickNote> => {
    return await createQuickNoteFromAudio(audioBlob, mode)
  }, [createQuickNoteFromAudio])

  // 更新处理模式
  const changeMode = useCallback(async (
    id: string,
    mode: ProcessingMode
  ): Promise<void> => {
    await updateQuickNoteMode(id, mode)
  }, [updateQuickNoteMode])

  // 更新情绪标签
  const updateMoods = useCallback(async (moods: string[]): Promise<void> => {
    await updateCurrentRecord({ moods })
  }, [updateCurrentRecord])

  // 更新需要标签
  const updateNeeds = useCallback(async (needs: string[]): Promise<void> => {
    await updateCurrentRecord({ needs })
  }, [updateCurrentRecord])

  // 更新转写文本
  const updateTranscription = useCallback(async (transcription: string): Promise<void> => {
    await updateCurrentRecord({ transcription })
  }, [updateCurrentRecord])

  // 确认 NVC 分析
  const confirmNVC = useCallback(async (): Promise<void> => {
    if (currentRecord && currentRecord.type === 'quick_note' && currentRecord.nvc) {
      await updateCurrentRecord({
        nvc: {
          ...currentRecord.nvc,
          userConfirmed: true
        }
      })
    }
  }, [currentRecord, updateCurrentRecord])

  // 修改 NVC 分析
  const modifyNVC = useCallback(async (nvcUpdates: any): Promise<void> => {
    if (currentRecord && currentRecord.type === 'quick_note' && currentRecord.nvc) {
      await updateCurrentRecord({
        nvc: {
          ...currentRecord.nvc,
          ...nvcUpdates,
          userModified: true
        }
      })
    }
  }, [currentRecord, updateCurrentRecord])

  // 删除当前记录
  const deleteCurrent = useCallback(async (): Promise<void> => {
    await deleteCurrentRecord()
  }, [deleteCurrentRecord])

  return {
    // 状态
    currentQuickNote: currentRecord?.type === 'quick_note' ? currentRecord as QuickNote : null,
    isProcessing,
    processingStage,
    error,

    // 操作方法
    createFromAudio,
    changeMode,
    updateMoods,
    updateNeeds,
    updateTranscription,
    confirmNVC,
    modifyNVC,
    deleteCurrent,
    clearCurrent
  }
}
