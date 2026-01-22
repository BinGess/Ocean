/**
 * 记录数据库操作
 */

import { db } from './schema'
import { Record, RecordType, QuickNote, Journal } from '../../models'
import { getDayKey } from '../../utils/date'

/**
 * 创建记录
 */
export async function createRecord(record: Record): Promise<Record> {
  await db.records.add(record)
  console.log('✅ Record created:', record.id)
  return record
}

/**
 * 更新记录
 */
export async function updateRecord(
  id: string,
  updates: Partial<Record>
): Promise<Record> {
  const existing = await db.records.get(id)
  if (!existing) {
    throw new Error(`Record not found: ${id}`)
  }

  const updated = {
    ...existing,
    ...updates,
    updatedAt: new Date().toISOString()
  }

  await db.records.put(updated)
  console.log('✅ Record updated:', id)
  return updated
}

/**
 * 删除记录
 */
export async function deleteRecord(id: string): Promise<void> {
  await db.records.delete(id)
  console.log('🗑️ Record deleted:', id)
}

/**
 * 根据 ID 获取记录
 */
export async function getRecordById(id: string): Promise<Record | undefined> {
  return await db.records.get(id)
}

/**
 * 获取所有记录（按创建时间倒序）
 */
export async function getAllRecords(limit?: number): Promise<Record[]> {
  let query = db.records.orderBy('createdAt').reverse()

  if (limit) {
    return await query.limit(limit).toArray()
  }

  return await query.toArray()
}

/**
 * 根据类型获取记录
 */
export async function getRecordsByType(
  type: RecordType,
  limit?: number
): Promise<Record[]> {
  let query = db.records
    .where('type')
    .equals(type)
    .reverse()

  if (limit) {
    return await query.limit(limit).toArray()
  }

  return await query.toArray()
}

/**
 * 获取指定日期的所有记录
 */
export async function getRecordsByDate(date: Date | string): Promise<Record[]> {
  const dayKey = getDayKey(date)
  const startOfDay = new Date(dayKey)
  const endOfDay = new Date(dayKey)
  endOfDay.setDate(endOfDay.getDate() + 1)

  return await db.records
    .where('createdAt')
    .between(startOfDay.toISOString(), endOfDay.toISOString(), true, false)
    .reverse()
    .toArray()
}

/**
 * 获取指定日期的日记（最多1篇）
 */
export async function getJournalByDate(date: Date | string): Promise<Journal | undefined> {
  const dayKey = getDayKey(date)

  const journals = await db.records
    .where('[type+createdAt]')
    .between(
      [RecordType.JOURNAL, new Date(dayKey).toISOString()],
      [RecordType.JOURNAL, new Date(dayKey + 'T23:59:59.999Z').toISOString()],
      true,
      true
    )
    .toArray()

  return journals[0] as Journal | undefined
}

/**
 * 获取指定日期的碎片记录
 */
export async function getQuickNotesByDate(date: Date | string): Promise<QuickNote[]> {
  const dayKey = getDayKey(date)
  const startOfDay = new Date(dayKey)
  const endOfDay = new Date(dayKey)
  endOfDay.setDate(endOfDay.getDate() + 1)

  const records = await db.records
    .where('[type+createdAt]')
    .between(
      [RecordType.QUICK_NOTE, startOfDay.toISOString()],
      [RecordType.QUICK_NOTE, endOfDay.toISOString()],
      true,
      false
    )
    .reverse()
    .toArray()

  return records as QuickNote[]
}

/**
 * 获取日期范围内的记录
 */
export async function getRecordsByDateRange(
  startDate: string,
  endDate: string
): Promise<Record[]> {
  const start = new Date(startDate).toISOString()
  const end = new Date(endDate + 'T23:59:59.999Z').toISOString()

  return await db.records
    .where('createdAt')
    .between(start, end, true, true)
    .reverse()
    .toArray()
}

/**
 * 获取最近 N 天的记录
 */
export async function getRecentRecords(days: number): Promise<Record[]> {
  const endDate = new Date()
  const startDate = new Date()
  startDate.setDate(startDate.getDate() - days)

  return await getRecordsByDateRange(
    getDayKey(startDate),
    getDayKey(endDate)
  )
}

/**
 * 搜索记录（根据转写内容）
 */
export async function searchRecords(query: string): Promise<Record[]> {
  const allRecords = await db.records.toArray()
  const lowerQuery = query.toLowerCase()

  return allRecords.filter(record =>
    record.transcription.toLowerCase().includes(lowerQuery)
  )
}

/**
 * 获取记录统计
 */
export async function getRecordsStats(): Promise<{
  total: number
  quickNotes: number
  journals: number
  thisWeek: number
  thisMonth: number
}> {
  const all = await db.records.toArray()
  const now = new Date()
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)

  return {
    total: all.length,
    quickNotes: all.filter(r => r.type === RecordType.QUICK_NOTE).length,
    journals: all.filter(r => r.type === RecordType.JOURNAL).length,
    thisWeek: all.filter(r => new Date(r.createdAt) > weekAgo).length,
    thisMonth: all.filter(r => new Date(r.createdAt) > monthAgo).length
  }
}
