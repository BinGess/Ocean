# 深入分析结果存储边界

## 当前客户端实现

- 深入分析结果不写入现有 Record/NVC 服务端协议。
- 客户端使用 Hive `settings` box，以 `deep_analysis_v1_<recordId>` 为 key 单独保存。
- 新记录创建成功并取得 `recordId` 后写入；同一记录可保存多条深入分析。
- 不同方法按生成顺序向下陈列；同一种方法再次分析时更新原结果，不重复堆叠。
- 删除记录时同步删除本机对应的深入分析结果。
- 从记录列表再次打开 NVC 结果页时，客户端按 `recordId` 恢复深入分析模块。

## 当前服务端改动

**无。**

客户端没有修改 `OceanRecordSyncMapper.toServerRecord()` 的 payload，也没有向现有 Record API 发送未知字段。

## 当前限制

- 深入分析结果只保存在当前设备。
- 换设备、卸载 App 或清空本地数据后无法恢复。
- 登录后的 Record 云同步仍正常，但不会同步深入分析结果。

## 未来如需跨设备同步

服务端可在 Record 模型中增加可选数组字段 `deepAnalyses`，旧记录允许为空数组或 `null`。建议结构：

```json
[
  {
    "type": "selfCompassion",
    "title": "站回自己这边",
    "methodLabel": "Self-Compassion",
    "theorySource": "源自自我同情与慈悲聚焦取向",
    "overview": "方法概述",
    "stuckPoint": "卡点结论",
    "groundedUnderstanding": "理解结论",
    "oneSmallStep": "行动建议",
    "steadySentence": "支持性表达",
    "analyzedAt": "2026-06-07T10:00:00.000Z"
  }
]
```

服务端需要同步支持：

1. Record 创建与更新接口接收、校验并保存可选 `deepAnalyses`。
2. Record 列表、详情、快照和增量同步接口返回该字段。
3. 对旧客户端保持兼容，未知或缺失字段不影响现有 NVC 数据。

服务端上线后，客户端再将该字段接入 `Record` 与 `OceanRecordSyncMapper`，并迁移本地 Hive 结果。
