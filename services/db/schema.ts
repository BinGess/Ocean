/**
 * IndexedDB Schema (使用 Dexie.js)
 */

import Dexie, { Table } from 'dexie'
import { Record, WeeklyInsight } from '../../models'

/**
 * MindFlow 数据库
 */
export class MindFlowDatabase extends Dexie {
  // 记录表（碎片、日记、周记）
  records!: Table<Record, string>

  // 周洞察表
  weeklyInsights!: Table<WeeklyInsight, string>

  constructor() {
    super('MindFlowDB')

    this.version(1).stores({
      // records 表索引
      // 主键: id
      // 索引: type, createdAt, type+createdAt 组合索引
      records: 'id, type, createdAt, [type+createdAt], updatedAt',

      // weeklyInsights 表索引
      weeklyInsights: 'id, weekRange, generatedAt'
    })
  }
}

// 导出单例实例
export const db = new MindFlowDatabase()

/**
 * 初始化数据库
 */
export async function initDatabase(): Promise<void> {
  try {
    await db.open()
    console.log('✅ Database initialized successfully')
  } catch (error) {
    console.error('❌ Failed to initialize database:', error)
    throw error
  }
}

/**
 * 清空所有数据（用于测试）
 */
export async function clearAllData(): Promise<void> {
  await db.records.clear()
  await db.weeklyInsights.clear()
  console.log('🗑️ All data cleared')
}

/**
 * 导出所有数据（用于备份）
 */
export async function exportAllData(): Promise<{
  records: Record[]
  weeklyInsights: WeeklyInsight[]
}> {
  const records = await db.records.toArray()
  const weeklyInsights = await db.weeklyInsights.toArray()

  return {
    records,
    weeklyInsights
  }
}

/**
 * 导入数据（用于恢复备份）
 */
export async function importData(data: {
  records: Record[]
  weeklyInsights: WeeklyInsight[]
}): Promise<void> {
  await db.transaction('rw', db.records, db.weeklyInsights, async () => {
    // 清空现有数据
    await db.records.clear()
    await db.weeklyInsights.clear()

    // 导入新数据
    await db.records.bulkAdd(data.records)
    await db.weeklyInsights.bulkAdd(data.weeklyInsights)
  })

  console.log('✅ Data imported successfully')
}
