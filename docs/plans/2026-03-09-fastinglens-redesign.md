# FastingLens v2 - 全面重新设计方案

> 日期：2026-03-09
> 状态：已确认
> 目标用户：自用 + 小圈子

---

## 1. App 重新定位

**从**：16+8 断食计时器 + 拍照识别记餐工具 + 手表快捷提醒器
**到**：**AI 减肥私人助手** —— 通过对话式交互完成所有记录，用数据可视化追踪进度

**核心理念**：**AI 是大脑，对话是入口**。所有数据记录和计划调整都由 AI 通过 Tool Calling 自主完成，用户只需自然聊天。

---

## 2. 信息架构：4 Tab 导航

| Tab | 名称 | SF Symbol | 核心职责 |
|-----|------|-----------|----------|
| 1 | **今天** | `house.fill` | 断食状态仪表盘 + 今日摘要 + AI 快捷入口 |
| 2 | **助手** | `bubble.left.and.text.bubble.right.fill` | AI 对话界面，所有记录通过聊天完成 |
| 3 | **数据** | `chart.bar.fill` | 体重趋势 + 热量统计 + 打卡日历 + 历史记录 |
| 4 | **我的** | `person.fill` | 个人设置 + 断食计划 + AI 配置 + 目标管理 |

**关键改动**：
- 去掉独立的"识别"和"记录"tab，全部收进"助手"对话
- "计划"tab 收进"我的"作为子页面
- 新增"数据"tab 做可视化

---

## 3. Tab 1 —「今天」首页

### 布局（从上到下）

#### 3.1 减肥总目标进度条（顶部横条）
- 横向进度条：`起始体重 ━━━●━━━ 目标体重`
- 显示当前体重和完成百分比
- 进度由 AI 根据起始体重和目标体重自动计算

#### 3.2 断食状态卡片（主视觉，约 35% 屏幕）
- 大圆环进度指示器，中心显示**剩余时间**（大字体）
- 圆环上方：当前阶段标签（"断食中" 或 "进食窗口"）
- 圆环下方：阶段起止时间
- 背景色随阶段变化（断食 → 渐变橙，进食 → 薄荷绿）
- AI 计算的本轮断食周期进度（第 X 天 / 共 Y 天）

#### 3.3 今日摘要（3 指标横排卡片）

| 指标 | 内容 | 样式 |
|------|------|------|
| 热量 | `856 / 1600 kcal` | 圆形进度条 + 数字 |
| 饮水 | `3 / 8 杯` | 水滴图标 + 进度条 |
| 体重 | `62.5 kg ↓0.3` | 趋势箭头 + 差值 |

纯展示，不可编辑。要改就找 AI。

#### 3.4 AI 快捷入口（按钮组）

点击即跳到「助手」Tab 并自动发起对应对话：

| 按钮 | 行为 |
|------|------|
| 📸 拍照记餐 | 打开相机 → 拍完跳 AI Tab，AI 识别并记录 |
| 🍕 放纵餐 | 跳 AI Tab，AI 知道要吃放纵餐，调整后续计划 |
| 💧 记饮水 | 跳 AI Tab，发送"喝了一杯水" |
| ⚖️ 记体重 | 跳 AI Tab，发送"今天体重 XX" |

**原则**：首页只展示数据，所有写入操作通过 AI 完成。快捷按钮是"预填对话"的入口。

#### 3.5 连续打卡条（底部）
- 显示：「已连续打卡 X 天」
- 每天完成至少一次断食周期即算打卡

---

## 4. Tab 2 —「助手」AI 对话界面

### 4.1 核心设计理念

**AI 是真正的对话代理**。App 提供一组 Tool（function calling），AI 自主判断何时调用什么工具。用户只需自然聊天，无需学习任何命令。

### 4.2 界面设计

**整体布局**：类似 iMessage / ChatGPT 的对话气泡界面

**顶部栏**：
- 左侧：助手头像 + 名字（可自定义）
- 右侧：「新对话」按钮（手动清空上下文）

**对话区域**：
- 用户消息：右侧气泡，`flame` 橙色底，白色文字
- AI 回复：左侧气泡，白色底 + `mint` 左边框
- 支持消息类型：纯文字、图片+文字、AI 生成的结构化卡片

**底部输入栏**：
- 文字输入框
- 📸 相机按钮
- 🖼 相册按钮

### 4.3 上下文管理

- 聊天记录全部本地保存
- 发送给 AI 时带完整历史，直到用户手动点"新对话"
- 用户完全掌控上下文生命周期
- 不做自动分段

### 4.4 App 提供给 AI 的工具接口

AI 完全自主判断调用时机，App 只负责：
1. 把工具列表和描述传给 AI
2. 执行 AI 返回的工具调用
3. 把执行结果发回 AI

| 工具名 | 功能描述 |
|--------|----------|
| `record_meal` | 记录一餐（类型、食物列表、各项热量） |
| `recognize_food` | 识别图片中的食物并返回热量估算 |
| `record_weight` | 记录体重 |
| `record_water` | 记录饮水（杯数、类型） |
| `mark_cheat_meal` | 标记放纵餐并触发计划调整逻辑 |
| `adjust_plan` | 调整断食计划（时长、热量目标等） |
| `get_today_summary` | 查询今日数据（热量、饮水、体重、断食状态） |
| `get_weight_trend` | 查询近期体重趋势数据 |
| `get_weekly_report` | 生成本周综合报告数据 |

### 4.5 AI 确认卡片

当 AI 调用工具后，结果渲染为可操作卡片嵌入对话中：

```
┌─────────────────────────────┐
│ 🍜 午餐识别结果              │
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
│ 牛肉面       480 kcal       │
│ 煎蛋         120 kcal       │
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
│ 合计: 600 kcal  置信度: 85% │
│                             │
│   [✓ 确认保存]  [✎ 修改]    │
└─────────────────────────────┘
```

用户可直接在卡片上操作（确认、修改），也可以继续用对话修改。

---

## 5. Tab 3 —「数据」统计与历史

### 5.1 时间维度切换
顶部 Segmented Control：`日` / `周` / `月`，影响所有图表

### 5.2 体重趋势图（折线图）
- X 轴：日期，Y 轴：体重
- 标注起始体重和目标体重虚线
- 数据点可点击查看具体数值
- 颜色：`flame` 主线 + `mint` 目标线

### 5.3 热量统计图（柱状图）
- 每天一根柱子，分段表示不同餐次
- 虚线标注每日热量目标
- 超标日柱子变 `coral` 红色

### 5.4 断食打卡日历（热力图）
- 月视图格子（类似 GitHub contribution）
- 完成断食 = `mint` 绿 / 部分完成 = 浅绿 / 未完成 = 灰
- 放纵餐日 = `flame` 橙标记
- 连续打卡天数统计

### 5.5 饮水统计
- 每日饮水量柱状图 + 目标线

### 5.6 历史餐食记录（列表）
- 按日期分组
- 每条：餐次类型 + 食物摘要 + 热量 + 时间
- 点击展开详情（食物明细 + 照片缩略图）
- 左滑删除

---

## 6. Tab 4 —「我的」设置与管理

### 6.1 个人信息卡片（顶部）
- 头像 + 称呼
- 减肥目标概览：`起始 → 目标`，已减 X kg
- 加入天数

### 6.2 断食计划（子页面）
- 当前计划显示（如 `16:8 断食`）
- 断食时长、进食窗口、周期起点、提醒开关
- "让 AI 推荐计划"入口（跳助手 Tab）

### 6.3 目标设置
- 目标体重（数字滚轮）
- 每日热量目标
- 每日饮水目标（杯数）
- 起始体重（初次设定后锁定，长按可改）

### 6.4 偏好设置
- 默认餐次类型
- 是否保存原图
- 通知提醒开关

### 6.5 AI 模型配置（子页面，双模式）

**表单模式**（默认）：
- 服务商名称
- API 地址
- API Key（密码输入框）
- 模型名称
- 常见预设下拉（OpenAI / Claude / 自定义）
- 连接测试按钮

**JSON 模式**（高级）：
- 切换开关切换到 JSON 编辑器
- 与表单模式数据互通，同一份数据不同展示方式

### 6.6 数据管理
- 导出数据（JSON）
- 清除所有数据（二次确认）

---

## 7. UI 视觉系统

### 7.1 色彩系统

| Token | 色值 | 用途 |
|-------|------|------|
| `lavender` | `#F5F0FF` | 主背景色 |
| `snow` | `#FFFFFF` | 卡片背景 |
| `flame` | `#FF6B35` | 主强调色（按钮、进度条、用户气泡） |
| `mint` | `#4ECDC4` | 成功/正向指标（达标、减重、完成） |
| `lemon` | `#FFE66D` | 点缀高亮（打卡火焰、警告） |
| `ink` | `#1A1A2E` | 主文字色 |
| `slate` | `#6B7280` | 次要文字 |
| `cloud` | `#E8E4F0` | 分隔线、禁用态 |
| `coral` | `#FF4757` | 超标警告、删除 |

**暗色模式**：
| Token | 色值 |
|-------|------|
| 背景 | `#0F0F1A` |
| 卡片 | `#1A1A2E` |
| 文字 | `#E8E4F0` |
| 强调色 | 保持不变 |

### 7.2 字体系统

| Token | 大小 | 字重 | 设计 | 用途 |
|-------|------|------|------|------|
| `heroTitle` | 32pt | Bold | Rounded | 大数字（剩余时间、体重） |
| `sectionTitle` | 20pt | Semibold | Default | 区块标题 |
| `body` | 16pt | Regular | Default | 正文、对话气泡 |
| `caption` | 13pt | Medium | Rounded | 标签、次要信息 |
| `digits` | 28pt | Heavy | Monospaced | 热量数字、进度百分比 |

### 7.3 卡片样式
- 圆角：16pt，连续曲线 (`.continuous`)
- 阴影：`color: ink.opacity(0.06), radius: 12, y: 4`
- 内边距：16pt
- 卡片间距：12pt

### 7.4 对话气泡样式
- **用户气泡**：`flame` 背景，白色文字，右下圆角缩小（尾巴效果）
- **AI 气泡**：`snow` 背景，`mint` 左边框 3pt，`ink` 文字
- 圆角：18pt
- 最大宽度：屏幕 75%

### 7.5 动效
- 页面切换：弹性滑入（spring animation）
- 打卡成功：confetti 粒子效果
- 进度变化：数字跳动动画（`.contentTransition(.numericText)`）
- 断食阶段切换：背景渐变色平滑过渡

### 7.6 Tab Bar 样式
- 选中态：`flame` 色 + filled 图标
- 未选中：`slate` 色 + outline 图标

---

## 8. Watch 端适配

- 保持 `flame` / `mint` 主色
- 简化为单屏状态卡 + 快捷操作列表
- 文字更大，减少信息密度
- 快捷操作（开始断食、打开进食窗口、记一餐）保留

---

## 9. 技术架构

### 9.1 新增数据模型

```swift
// 体重记录
struct WeightRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double  // kg
}

// 饮水记录
struct WaterRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let cups: Int
    let note: String?  // "咖啡"、"白开水"等
}

// AI 对话消息
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: Role  // .user / .assistant / .system
    let content: String
    let imageFileName: String?
    let toolCalls: [ToolCall]?
    let toolResult: ToolResult?
    let createdAt: Date

    enum Role: String, Codable { case user, assistant, system }
}

// 对话会话（用户手动管理）
struct ChatSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var messages: [ChatMessage]
    var title: String?
}

// 打卡记录
struct CheckInRecord: Codable {
    let date: Date
    let fastingCompleted: Bool
    let isCheatDay: Bool
}

// AI 工具调用
struct ToolCall: Codable {
    let name: String
    let arguments: String  // JSON string
}

struct ToolResult: Codable {
    let toolName: String
    let result: String  // JSON string
}
```

### 9.2 AI Tool Calling 流程

```
用户输入
  → App 构建请求（完整历史消息 + 工具定义 JSON Schema）
  → 发送到 AI Provider（OpenAI-compatible API）
  → AI 返回：文本回复 or 工具调用
  → 如果是工具调用：
      → App 执行工具（记录数据 / 查询数据 / 调整计划）
      → 把执行结果发回 AI
      → AI 生成最终回复（可能继续调用工具）
  → 渲染到对话界面（文字 + 结构化卡片）
```

### 9.3 文件结构

```
FastingLensApp/Sources/
├── FastingLensApp.swift
├── AppState.swift              // 改：新增 weight/water/chat/checkIn 管理
├── Models/
│   ├── MealModels.swift        // 拆出：餐食相关模型
│   ├── WeightModels.swift      // 新增：体重记录
│   ├── WaterModels.swift       // 新增：饮水记录
│   └── ChatModels.swift        // 新增：对话/工具/会话模型
├── AI/
│   ├── ChatService.swift       // 新增：对话服务（含 tool calling 循环）
│   ├── ToolDefinitions.swift   // 新增：所有工具的 JSON Schema 定义
│   ├── ToolExecutor.swift      // 新增：工具执行器（调 AppState 方法）
│   └── MealRecognitionService.swift  // 保留：图片识别（被 recognize_food 工具调用）
├── Views/
│   ├── TodayTab/               // Tab 1: 首页
│   │   ├── TodayScreen.swift
│   │   ├── GoalProgressBar.swift
│   │   ├── FastingStatusCard.swift
│   │   ├── TodaySummaryRow.swift
│   │   └── QuickActionButtons.swift
│   ├── AssistantTab/           // Tab 2: AI 对话
│   │   ├── AssistantScreen.swift
│   │   ├── ChatBubbleView.swift
│   │   ├── ToolResultCard.swift    // 结构化卡片组件
│   │   └── ChatInputBar.swift
│   ├── DataTab/                // Tab 3: 数据
│   │   ├── DataScreen.swift
│   │   ├── WeightChartView.swift
│   │   ├── CalorieChartView.swift
│   │   ├── CheckInCalendar.swift
│   │   ├── WaterChart.swift
│   │   └── MealHistoryList.swift
│   ├── ProfileTab/             // Tab 4: 我的
│   │   ├── ProfileScreen.swift
│   │   ├── PlanSettingsView.swift
│   │   ├── GoalSettingsView.swift
│   │   ├── AIConfigView.swift      // 双模式：表单 + JSON
│   │   └── DataManageView.swift
│   └── Components/             // 共享组件
│       ├── ActionPill.swift
│       └── ProgressRing.swift
├── Theme/
│   └── FastingLensTheme.swift  // 改：新色彩 + 新字体系统
├── ReminderScheduler.swift
├── CameraPicker.swift
└── WatchSyncBridge.swift
```

### 9.4 AI 配置双模式

表单和 JSON 编辑同一份 `ProviderConfig` 数据。切换模式时：
- 表单 → JSON：将当前 ProviderConfig 序列化为 JSON 显示
- JSON → 表单：解析 JSON 填充到表单字段
- 验证逻辑复用现有 `AISettingsDraft.validate()`

---

## 10. 与现有代码的对应关系

| 现有文件 | 变化 |
|----------|------|
| `Screens.swift` | **拆分**为 `TodayTab/`、`AssistantTab/`、`DataTab/`、`ProfileTab/` |
| `AppState.swift` | **扩展**：新增 weight、water、chat、checkIn 数据管理 |
| `MealRecognitionService.swift` | **保留**：被 `ToolExecutor` 中的 `recognize_food` 工具调用 |
| `FastingLensTheme.swift` | **重写**：新色彩系统（lavender/flame/mint/lemon） |
| `AISettingsDraft.swift` | **扩展**：支持表单模式的字段级验证 |
| `ProviderConfig.swift` | **扩展**：新增 tool calling 相关配置字段 |
| `DashboardView.swift` | **改造**：适配新的首页卡片设计 |
| Watch / Widget | **保持**结构，适配新色彩 |

---

## 11. 不在本次范围内

- iCloud/CloudKit 同步
- 语音输入
- 社交分享
- App Store 上架相关（隐私政策、截图等）
- 高级营养分析（微量营养素等）
