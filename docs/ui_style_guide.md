# MindFlow UI 统一风格规范（v1）

## 1. 视觉方向
- 关键词：`calm`、`warm`、`readable`
- 场景定位：情绪记录与反思，避免高饱和与强对比冲击
- 设计目标：减少视觉噪音，突出文本可读性与操作反馈

## 2. 颜色系统（语义化）
- 主色：`AppColors.primary #C4A57B`
- 主色深：`AppColors.primaryDark #9D7D56`
- 主色浅底：`AppColors.primarySoft #F5EBE0`
- 文字主级：`AppColors.textPrimary #2C2C2C`
- 文字次级：`AppColors.textSecondary #5D4E3C`
- 文字辅助：`AppColors.textTertiary #8B7D6B`
- 页面背景：`AppColors.background #FAF6F1`
- 卡片背景：`AppColors.surface #FFFFFF`
- 次级卡片：`AppColors.surfaceSecondary #F7F0E8`
- 分割/边框：`AppColors.border #E0D5C5`
- 状态色：
  - 成功：`AppColors.success`
  - 警告：`AppColors.warning`
  - 错误：`AppColors.error`

## 3. 字体层级
- 字体家族：
  - Sans：`Noto Sans SC`
  - Serif：`Noto Serif SC`
- 主标题：`AppTypography.pageTitle`（24/600）
- 区块标题：`AppTypography.sectionTitle`（16/600）
- 正文：`AppTypography.bodyPrimary`（15/500）
- 辅助正文：`AppTypography.bodySecondary`（14/400）
- 时间/说明：`AppTypography.sectionSubtle`（12/500）

## 4. 间距与圆角
- 基础 4pt 网格：`4/8/12/16/20/24/32`
- 页面横向边距：`AppSpacing.pageHorizontal = 20`
- 常规卡片内边距：`AppSpacing.lg(16)` / `AppSpacing.xl(20)`
- 常规圆角：`AppSpacing.cardRadius = 12`
- 大卡片圆角：`AppSpacing.cardRadiusLg = 20`

## 5. 组件统一规则
- 所有按钮、卡片、输入框优先走 `ThemeData` + `AppTypography/AppColors/AppSpacing`
- 禁止新增十六进制硬编码色（特殊海报/纹理背景除外）
- 同类型控件的 hover/pressed/disabled 反馈保持统一语义色
- 列表卡片阴影统一低强度（透明黑 2%-6%）

## 6. 可访问性最低要求
- 正文文本与背景对比至少 4.5:1
- 触控目标建议不小于 44x44
- 正文行高维持 1.58~1.65 区间

