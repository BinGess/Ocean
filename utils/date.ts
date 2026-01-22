/**
 * 日期处理工具函数
 */

/**
 * 生成 day key（YYYY-MM-DD 格式）
 */
export function getDayKey(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * 获取星期几（中文）
 */
export function getDayOfWeek(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  return days[d.getDay()]
}

/**
 * 格式化日期为友好格式
 * @example "1月22日 周一"
 */
export function formatFriendlyDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const month = d.getMonth() + 1
  const day = d.getDate()
  const dayOfWeek = getDayOfWeek(d)
  return `${month}月${day}日 ${dayOfWeek}`
}

/**
 * 格式化日期时间
 * @example "2025-01-22 14:30"
 */
export function formatDateTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const hours = String(d.getHours()).padStart(2, '0')
  const minutes = String(d.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}`
}

/**
 * 格式化时间（仅时分）
 * @example "14:30"
 */
export function formatTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const hours = String(d.getHours()).padStart(2, '0')
  const minutes = String(d.getMinutes()).padStart(2, '0')
  return `${hours}:${minutes}`
}

/**
 * 获取今天的 day key
 */
export function getTodayKey(): string {
  return getDayKey(new Date())
}

/**
 * 获取昨天的 day key
 */
export function getYesterdayKey(): string {
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  return getDayKey(yesterday)
}

/**
 * 获取指定天数前的 day key
 */
export function getDaysAgoKey(days: number): string {
  const date = new Date()
  date.setDate(date.getDate() - days)
  return getDayKey(date)
}

/**
 * 获取本周的日期范围
 * @returns { start: 'YYYY-MM-DD', end: 'YYYY-MM-DD' }
 */
export function getThisWeekRange(): { start: string; end: string } {
  const now = new Date()
  const dayOfWeek = now.getDay()
  const monday = new Date(now)
  monday.setDate(now.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1))

  const sunday = new Date(monday)
  sunday.setDate(monday.getDate() + 6)

  return {
    start: getDayKey(monday),
    end: getDayKey(sunday)
  }
}

/**
 * 格式化周范围
 * @example "2025-01-13 ~ 2025-01-19"
 */
export function formatWeekRange(start: string, end: string): string {
  return `${start} ~ ${end}`
}

/**
 * 判断是否是今天
 */
export function isToday(date: Date | string): boolean {
  return getDayKey(date) === getTodayKey()
}

/**
 * 判断是否是昨天
 */
export function isYesterday(date: Date | string): boolean {
  return getDayKey(date) === getYesterdayKey()
}

/**
 * 获取相对时间描述
 * @example "刚刚", "5分钟前", "1小时前", "昨天", "2天前"
 */
export function getRelativeTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const now = new Date()
  const diffMs = now.getTime() - d.getTime()
  const diffMinutes = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMinutes < 1) return '刚刚'
  if (diffMinutes < 60) return `${diffMinutes}分钟前`
  if (diffHours < 24) return `${diffHours}小时前`
  if (diffDays === 1) return '昨天'
  if (diffDays < 7) return `${diffDays}天前`

  return formatFriendlyDate(d)
}

/**
 * 解析 ISO 8601 日期字符串
 */
export function parseISODate(isoString: string): Date {
  return new Date(isoString)
}

/**
 * 转换为 ISO 8601 格式
 */
export function toISOString(date: Date): string {
  return date.toISOString()
}

/**
 * 格式化为"距离现在"的时间描述
 * @example "刚刚", "5分钟前", "1小时前", "昨天 14:30", "1月20日"
 */
export function formatDistanceToNow(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const now = new Date()
  const diffMs = now.getTime() - d.getTime()
  const diffMinutes = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  // 1分钟内：刚刚
  if (diffMinutes < 1) return '刚刚'

  // 1小时内：X分钟前
  if (diffMinutes < 60) return `${diffMinutes}分钟前`

  // 24小时内：X小时前
  if (diffHours < 24) return `${diffHours}小时前`

  // 昨天：昨天 HH:MM
  if (isYesterday(d)) {
    return `昨天 ${formatTime(d)}`
  }

  // 7天内：X天前
  if (diffDays < 7) return `${diffDays}天前`

  // 更早：月日
  const month = d.getMonth() + 1
  const day = d.getDate()
  return `${month}月${day}日`
}
