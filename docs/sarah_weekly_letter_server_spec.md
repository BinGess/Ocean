# Sarah 周报 — 服务端改造说明

> 背景：原方案由客户端每次打开 Sarah 页时调用 `POST /sarah/letters/generate-weekly` 触发生成，
> 存在重复触发、时机不可控、周期范围计算错误等问题。
> 新方案将生成职责完全移到服务端，客户端只负责拉取展示。

---

## 一、整体架构变化

| | 旧方案 | 新方案 |
|---|---|---|
| **谁触发生成** | 客户端（每次打开 Sarah 页） | 服务端 Cron 定时任务 |
| **触发时机** | 用户进入页面时，不可控 | 每周日 20:00 CST，固定可控 |
| **覆盖周期** | 「本周」（当前进行中的周，范围错误） | 「本周一 00:00 ~ 本周日 20:00」 |
| **客户端接口** | 调 `POST generate-weekly` 主动生成 | 只调 `GET /sarah/letters` 拉取 |
| **重复风险** | 高（每次打开都触发） | 低（有幂等校验） |

---

## 二、新增 Cron 任务

### 触发时机

```
每周日 20:00（中国标准时间 CST / UTC+8）
Cron 表达式：0 20 * * 0   (Asia/Shanghai)
```

### 执行逻辑（伪代码）

```
function generateWeeklySarahLetters():

  # 计算本周周期
  weekStart = 本周一 00:00:00 CST
  weekEnd   = 本周日 20:00:00 CST   # 即 Cron 执行时刻

  # 遍历所有注册用户
  for user in getAllActiveUsers():

    # 幂等校验：本周是否已生成过
    existing = db.sarahLetters.findOne(
      userId    = user.id,
      type      = 'weekly',
      weekStart = weekStart,
      weekEnd   = weekEnd,
      deletedAt = null          # 排除已软删除
    )
    if existing != null:
      continue                  # 已有，跳过

    # 拉取本周记录
    records = db.records.findAll(
      userId    = user.id,
      createdAt >= weekStart,
      createdAt <= weekEnd,
    )

    # 无记录则不生成（用户本周没有写日记）
    if records.isEmpty:
      continue

    # 调用 Coze 生成信件内容
    content = coze.generate(
      template = 'sarah_weekly_letter',
      params   = {
        userId  : user.id,
        records : records,
        weekStart: weekStart,
        weekEnd  : weekEnd,
      }
    )

    # 保存到数据库
    db.sarahLetters.insert({
      id               : uuid(),
      userId           : user.id,
      type             : 'weekly',
      content          : content,
      weekStart        : weekStart,
      weekEnd          : weekEnd,
      illustrationIndex: random(1..20),
      isRead           : false,
      createdAt        : now(),
    })
```

### 关键约束

1. **幂等性**：同一用户同一 `weekStart` 只能存在一条未删除的 weekly 信件。
   建议在数据库加唯一索引：`UNIQUE (userId, type, weekStart)` where `deletedAt IS NULL`。

2. **无记录不生成**：用户本周没有任何情绪记录，不生成信件（`records.isEmpty → continue`）。

3. **异步/错误处理**：Coze 调用失败时跳过该用户，记录错误日志，不影响其他用户。建议：
   - 单个用户失败后写入 `failed_jobs` 表，供后续排查或重试
   - 整个 Cron 任务完成后发送执行摘要（成功/失败/跳过 各多少人）

---

## 三、`GET /sarah/letters` 接口确认

客户端拉取时调用此接口，需确保返回结果满足：

```
返回字段：
{
  "letters": [
    {
      "id"               : string,
      "type"             : "welcome" | "weekly" | "legacy",
      "content"          : string,
      "weekStart"        : ISO8601 | null,   // weekly 类型必填
      "weekEnd"          : ISO8601 | null,   // weekly 类型必填
      "illustrationIndex": number,
      "isRead"           : boolean,
      "createdAt"        : ISO8601,
      "updatedAt"        : ISO8601 | null,
      "deletedAt"        : ISO8601 | null,
    }
  ]
}

过滤规则：只返回 deletedAt IS NULL 的信件（软删除的不返回）
排序：createdAt DESC
```

---

## 四、`POST /sarah/letters/generate-weekly` 接口处理

这个接口是原来客户端主动触发用的，**客户端侧已移除调用**。

建议服务端保留该接口但限制权限（改为仅内部/管理员可调用），
方便未来测试补发信件，或手动为某个用户补生成一封指定周的信件：

```
POST /sarah/letters/generate-weekly
权限：internal / admin only
Body: { userId, weekStart, weekEnd }
```

---

## 五、客户端改动（已完成）

以下改动已在客户端代码中同步完成，服务端同事**无需关心**：

- `SarahBloc._onLoadRequested` 移除了 `_requestWeeklyLetterIfUseful()` 调用
- `SarahBloc` 构造器移除 `requestWeeklyLetterUseCase` 依赖
- DI 注入表移除 `RequestSarahWeeklyLetterUseCase` 注册
- 单元测试更新，增加「`didRequestWeekly == false`」断言验证客户端不再主动触发

客户端行为变为：打开 App → `GET /sarah/letters` → 展示服务端已生成的信件。

---

## 六、联调验证清单

服务端完成开发后，双端联调时按以下顺序验证：

- [ ] 周日 20:00 Cron 正常触发，日志可查
- [ ] 用户本周有记录 → Cron 后可在 Sarah 页看到新来信（未读红点）
- [ ] 用户本周无记录 → Cron 后 Sarah 页无新信，不报错
- [ ] 同一周触发两次 Cron → 不生成重复信件（幂等校验通过）
- [ ] 用户删除一封周报后 → 该周不会因 Cron 重新生成（`deletedAt` 字段逻辑正确）
- [ ] 客户端重装 App → 不产生重复欢迎信（已由之前 PR 修复）
