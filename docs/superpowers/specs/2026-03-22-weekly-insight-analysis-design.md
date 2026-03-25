# 周洞察数据分析增强设计

## 背景

当前洞察页主要展示基于 AI 生成的周报文案，内容偏主观表达。项目底层记录数据已经包含 `moods`、`needs`、`nvc` 与时间信息，但这些结构化字段尚未被用于当前周洞察页的本地统计与可视化展示。

## 目标

在保留现有 AI 周报能力的前提下，为周洞察页增加一层本地计算的周数据分析，让页面先展示可验证的事实，再展示 AI 的总结与建议。

## 范围

本次仅实现方案 A 的最小可用版本：

- 新增本地周分析实体与聚合逻辑
- 洞察页增加数据分析卡片
- 保留现有 `InsightReport` 生成与展示逻辑
- 不修改远端 AI 接口协议

本次不包含：

- 将周分析摘要反向喂给 AI
- 复杂图表
- 自由标签体系
- 情绪正负向评分与复杂波动模型

## 用户体验

洞察页的信息顺序调整为：

1. 顶部标题区
2. 本周概览卡
3. 情绪与需求分布卡
4. 节律与变化提醒卡
5. 现有 AI 情绪概览
6. 现有高频情境 / 潜在需求 / 行动建议

其中前四块由本地数据分析驱动，后续三块继续使用现有 `InsightReport`。

## 数据模型

新增 `WeeklyAnalysis` 实体，包含：

- `weekRange`
- `totalRecords`
- `activeDays`
- `longestStreak`
- `topMood`
- `topNeed`
- `topMoods`
- `topNeeds`
- `peakTimeBucket`
- `busiestWeekday`
- `moodTaggedCount`
- `needTaggedCount`
- `coverageSummary`
- `changesSummary`

辅助对象：

- `WeeklyTagStat`：标签名、次数、占比
- `WeeklyComparisonStat`：本周值、上周值、变化值

## 计算规则

### 数据来源

- `Record.createdAt`
- `Record.moods`
- `Record.needs`
- `Record.nvc.feelings`
- `Record.nvc.needs`

### 标签归一

- 优先使用 `record.moods` 与 `record.needs`
- 若 `record.moods` 为空，使用 `record.nvc.feelings[*].feeling`
- 若 `record.needs` 为空，使用 `record.nvc.needs[*].need`
- 对标签执行拆分、去空白、去重，保持和现有页面一致的清洗规则

### 指标定义

- 记录数：周内记录总数
- 活跃天数：至少有一条记录的自然日数量
- 最长连续记录天数：连续活跃自然日的最大长度
- Top 心情 / Top needs：按出现次数降序，最多取 3 个
- 高峰时段：按 `早晨(05-11) / 下午(12-17) / 晚上(18-22) / 深夜(23-04)` 统计
- 最密集记录日：周一至周日中记录数最多的日期
- 覆盖率说明：带 `moods` 的记录数与带 `needs` 的记录数
- 变化提醒：仅比较当前周与上一周的记录数、Top mood、Top need 的增减

## 状态流

- `InsightBloc` 在加载当前周洞察时，同时计算 `WeeklyAnalysis`
- `InsightState` 新增当前周分析字段
- 页面优先展示分析结果；若 AI 报告存在则继续展示 AI 区块
- 若 AI 生成失败但当前周分析可用，页面仍显示数据分析卡片

## 错误处理

- 本地分析不依赖 AI 授权
- 若一周内无记录，则沿用现有空状态
- 若标签覆盖率较低，仅显示保守文案，不做强结论

## 验证策略

- 为周分析聚合逻辑补充单元测试
- 覆盖：
  - 基础统计
  - 标签回退到 NVC
  - 时间桶统计
  - 上周对比
  - 空标签覆盖率

## 实现影响

- 新增领域实体与 use case
- 修改 `InsightBloc`、`InsightState`
- 修改洞察页 UI 结构
- 不改动现有 AI 接口与缓存协议
