# Ocean 情绪分析接口说明

> 背景：当前"本周概览"所有统计逻辑在客户端本地完成，存在时间分桶粗糙、百分比计算口径错误、无法支持跨周持续跟踪等问题。  
> 本文档定义将分析逻辑迁移至服务端所需的新增接口。

---

## 通用约定

| 项目 | 说明 |
|------|------|
| Base URL | 与现有接口相同 |
| 认证 | `Authorization: Bearer <access_token>`（与 `/records` 接口一致） |
| 用户标识 | 由 Token 解析，无需额外传 user_id |
| 时间格式 | ISO 8601，如 `2026-05-18T14:30:00+08:00` |
| 日期格式 | `YYYY-MM-DD` |
| 错误格式 | `{ "code": "ERROR_CODE", "message": "描述" }` |

---

## 接口列表

| # | Method | Path | 功能 |
|---|--------|------|------|
| 1 | GET | `/api/v1/analysis/weekly` | 获取周分析数据（替换客户端本地计算） |
| 2 | GET | `/api/v1/analysis/emotion-trend` | 情绪与需求长期趋势（新功能） |

---

## 1. 周分析数据

```
GET /api/v1/analysis/weekly
```

替代客户端 `BuildWeeklyAnalysisUseCase` 的全部逻辑，修正以下问题：
- 时间分桶更细，返回完整小时分布
- 百分比基于「包含该标签的记录数 / 本周有情绪标签的总记录数」，而非标签出现总次数
- 跨周对比基于同一标签名做差值，不再用 top1 互比
- 统一 `moods` 字段与 `nvc.feelings` 的标签提取口径

### Query Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `week` | string | 三选一 | ISO 周格式，如 `2026-W21` |
| `start_date` | string | 三选一 | 周起始日期，如 `2026-05-18` |
| `end_date` | string | 与 start_date 配合 | 周结束日期，如 `2026-05-24` |

> 推荐优先使用 `start_date` + `end_date`，由客户端根据本地时区计算后传入，避免服务端时区理解歧义。

### Response 200

```json
{
  "week_range": "2026-05-18 ~ 2026-05-24",
  "period": {
    "start": "2026-05-18",
    "end": "2026-05-24"
  },

  "overview": {
    "total_records": 12,
    "active_days": 5,
    "longest_streak": 3,
    "busiest_weekday": "周三",
    "busiest_weekday_count": 4
  },

  "peak_time": {
    "bucket": "晚上",
    "bucket_range": "18:00–22:59",
    "top_hours": [21, 20, 22],
    "hourly_distribution": [
      { "hour": 0,  "count": 0 },
      { "hour": 1,  "count": 0 },
      { "hour": 2,  "count": 1 },
      { "hour": 6,  "count": 2 },
      { "hour": 8,  "count": 3 },
      { "hour": 20", "count": 3 },
      { "hour": 21, "count": 5 },
      { "hour": 22, "count": 2 }
    ]
  },

  "emotions": {
    "coverage": {
      "total_records": 12,
      "records_with_mood": 9,
      "records_with_need": 8,
      "mood_coverage_rate": 0.75,
      "need_coverage_rate": 0.67
    },
    "top_moods": [
      {
        "label": "焦虑",
        "count": 5,
        "percentage": 55.6,
        "avg_intensity": 3.2,
        "vs_last_week": 2
      },
      {
        "label": "疲惫",
        "count": 3,
        "percentage": 33.3,
        "avg_intensity": 2.8,
        "vs_last_week": -1
      },
      {
        "label": "平静",
        "count": 1,
        "percentage": 11.1,
        "avg_intensity": null,
        "vs_last_week": 0
      }
    ],
    "top_needs": [
      {
        "label": "安全感",
        "count": 4,
        "percentage": 50.0,
        "vs_last_week": 1
      },
      {
        "label": "陪伴",
        "count": 3,
        "percentage": 37.5,
        "vs_last_week": 0
      }
    ]
  },

  "changes_vs_last_week": {
    "records_delta": 3,
    "active_days_delta": 1,
    "mood_shifts": [
      { "label": "焦虑", "delta": 2, "direction": "up" },
      { "label": "疲惫", "delta": -1, "direction": "down" }
    ],
    "need_shifts": [
      { "label": "安全感", "delta": 1, "direction": "up" }
    ]
  }
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `peak_time.hourly_distribution` | 仅返回 count > 0 的小时，客户端补全空项 |
| `peak_time.top_hours` | 最多 3 个，按 count 降序 |
| `emotions.top_moods[].percentage` | `count / records_with_mood * 100`，保留 1 位小数 |
| `emotions.top_moods[].avg_intensity` | 来自 `nvc.feelings.intensity`（1–5），若来源为 `moods` 字段则为 null |
| `emotions.top_moods[].vs_last_week` | 本周该标签出现次数 - 上周同名标签出现次数，可为负 |
| `changes_vs_last_week.mood_shifts` | 仅返回本周 top5 情绪的对比，排除 delta=0 的项 |

### 错误码

| HTTP | code | 说明 |
|------|------|------|
| 404 | `NO_RECORDS` | 该周无任何记录 |
| 400 | `INVALID_RANGE` | 日期范围超过 7 天或格式错误 |

---

## 3. 情绪与需求长期趋势

```
GET /api/v1/analysis/emotion-trend
```

用于"个人情绪持续跟进"功能，支持按天 / 周 / 月粒度查看情绪与需求的变化曲线。

### Query Parameters

| 参数 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| `start_date` | string | 是 | — | 如 `2026-04-01` |
| `end_date` | string | 是 | — | 如 `2026-05-23` |
| `granularity` | string | 否 | `week` | `day` \| `week` \| `month` |
| `top_n` | int | 否 | `5` | 返回频率最高的前 N 个情绪/需求 |

### Response 200

```json
{
  "period": {
    "start": "2026-04-01",
    "end": "2026-05-23",
    "granularity": "week"
  },
  "top_moods": ["焦虑", "疲惫", "平静", "烦躁", "开心"],
  "top_needs": ["安全感", "陪伴", "休息", "被理解", "自主"],

  "mood_trend": [
    {
      "period_label": "4/1–4/7",
      "period_start": "2026-04-01",
      "total_records": 8,
      "data": [
        { "label": "焦虑", "count": 3, "percentage": 37.5, "avg_intensity": 3.0 },
        { "label": "疲惫", "count": 2, "percentage": 25.0, "avg_intensity": 2.5 }
      ]
    },
    {
      "period_label": "4/8–4/14",
      "period_start": "2026-04-08",
      "total_records": 6,
      "data": [
        { "label": "焦虑", "count": 4, "percentage": 66.7, "avg_intensity": 3.8 },
        { "label": "平静", "count": 1, "percentage": 16.7, "avg_intensity": null }
      ]
    }
  ],

  "need_trend": [
    {
      "period_label": "4/1–4/7",
      "period_start": "2026-04-01",
      "total_records": 8,
      "data": [
        { "label": "安全感", "count": 3, "percentage": 37.5 },
        { "label": "陪伴",  "count": 2, "percentage": 25.0 }
      ]
    }
  ],

  "peak_time_trend": [
    {
      "period_label": "4/1–4/7",
      "period_start": "2026-04-01",
      "peak_bucket": "晚上",
      "top_hours": [21, 20]
    }
  ],

  "summary": {
    "dominant_mood": "焦虑",
    "dominant_mood_weeks": 6,
    "total_weeks": 8,
    "longest_mood_streak": {
      "label": "焦虑",
      "streak_periods": 3,
      "streak_start": "2026-04-08"
    }
  }
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `mood_trend[].data` | 仅包含 `top_moods` 列表中出现在该周期的项，缺失表示该周期 count=0 |
| `summary.dominant_mood_weeks` | 该情绪作为周期内 top1 的次数 |
| `summary.longest_mood_streak` | 同一情绪连续多个周期均为 top1 的最长连续段 |

### 错误码

| HTTP | code | 说明 |
|------|------|------|
| 400 | `RANGE_TOO_LARGE` | 查询范围超过 366 天 |
| 400 | `INVALID_GRANULARITY` | granularity 值不合法 |

---

## 客户端迁移说明

### 修改点

1. `InsightBloc._buildAnalysisForCurrentWeek` 改为调用 `GET /api/v1/analysis/weekly`，本地 `BuildWeeklyAnalysisUseCase` 保留作为离线降级
2. 新增趋势页面调用 `GET /api/v1/analysis/emotion-trend`

### 降级策略

| 场景 | 处理 |
|------|------|
| 网络不可用 | 展示本地计算结果，标注"离线数据" |
| 服务端返回 404/NO_RECORDS | 与现有逻辑一致，显示"本周暂无记录" |
