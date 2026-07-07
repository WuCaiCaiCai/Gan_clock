# 苷 · Gan Clock 架构文档

> 本文档是 Flutter 版架构的完整记录，也是 Kotlin 版重写的技术规格书。

---

## 一、项目概览

| 项目 | 值 |
|------|-----|
| 名称 | 苷 (Gan Clock) |
| 标识 | `tomato_clock` |
| 版本 | 0.1.1+2 |
| 类型 | 番茄钟专注计时器 |
| 平台 | Android (minSdk 31)，Linux/Fedora KDE |
| 设计语言 | Material Design 3，中性灰色基调 |
| 数据持久化 | 本地 JSON 文件 + 可选本地备份恢复 |
| 外部依赖 | 零第三方包（纯 SDK + 原生代码） |

---

## 二、整体架构分层

```
┌─────────────────────────────────────────────────────────┐
│  UI 层                                                  │
│  页面 (Timer/Stats/Settings) + 组件 (Ring/Actions/Fade) │
│  无业务逻辑，纯渲染 + 回调到 AppController               │
├─────────────────────────────────────────────────────────┤
│  AppController (状态编排层)                              │
│  ChangeNotifier，持有 TomatoData                         │
│  连接 TimerEngine → Storage → CompletionFeedback         │
│  Timer.periodic 驱动每秒 tick                            │
├─────────────────────────────────────────────────────────┤
│  TomatoTimerEngine (纯函数领域层)                        │
│  所有方法 const，输入 TomatoData 输出 TimerTickResult     │
│  无 I/O，无副作用，完全可测试                            │
├─────────────────────────────────────────────────────────┤
│  Models (数据模型层)                                     │
│  AppSettings / FocusSession / TimerSnapshot / TomatoData │
│  JSON 序列化/反序列化，schema 迁移                       │
├─────────────────────────────────────────────────────────┤
│  AppStorage (基础设施层)                                  │
│  本地 JSON 文件 I/O，原子写入 (tmp+rename)               │
│  本地备份创建/恢复，自动清理旧备份                       │
├─────────────────────────────────────────────────────────┤
│  PlatformControls (平台桥接层)                           │
│  MethodChannel → Android (Java) / Linux (C++)            │
│  PiP / 通知 / 常亮 / 震动 / 音效 / 文件选择              │
├─────────────────────────────────────────────────────────┤
│  External Services (外部服务层)                          │
│  WeatherService (Open-Meteo)                             │
│  HitokotoService (v1.hitokoto.cn)                        │
└─────────────────────────────────────────────────────────┘
```

---

## 三、核心数据模型

### 3.1 枚举

```kotlin
enum TimerMode { focus, shortBreak, longBreak }
enum TimerPhase { idle, running, paused }
enum HeatmapScope { month, year }
enum AppThemeMode { system, light, dark }
```

### 3.2 AppSettings — 用户设置

| 字段 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| focusMinutes | Int | 25 | 1-240 | 专注时长 |
| shortBreakMinutes | Int | 5 | 1-120 | 短休息时长 |
| longBreakMinutes | Int | 15 | 1-240 | 长休息时长 |
| roundsBeforeLongBreak | Int | 4 | 1-12 | 每 N 轮进入长休息 |
| focusCyclesPerRun | Int | 4 | 1-48 | 本轮循环次数 |
| idleFocusSeconds | Int | 30 | 5-600 | 无操作待机延时 |
| themeMode | AppThemeMode | system | - | 主题模式 |
| keepScreenOnEnabled | Boolean | false | - | 屏幕常亮 |
| pictureInPictureEnabled | Boolean | true | - | PiP 画中画 |
| completionSoundEnabled | Boolean | false | - | 完成提示音 |
| completionHapticsEnabled | Boolean | true | - | 完成震动 |
| localBackupDirectory | String | "" | - | 备份目录路径 |
| localBackupAutoEnabled | Boolean | false | - | 自动备份 |
| localBackupAutoIntervalMinutes | Int | 60 | 5-1440 | 自动备份间隔 |
| localBackupKeepCount | Int | 5 | 1-50 | 保留备份份数 |
| weatherEnabled | Boolean | true | - | 显示天气 |
| weatherCity | String | "" | - | 手动指定城市 |

**序列化要求**：
- 所有数值字段反序列化时需做 clamp 边界检查（`_boundedInt`）
- `themeMode` 需兼容旧版 `darkModeEnabled` 布尔字段
- `toJson()` / `fromJson()` 完整实现

### 3.3 FocusSession — 专注记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 唯一标识（`focus-{微秒时间戳}`） |
| startedAt | DateTime | 开始时间 |
| endedAt | DateTime | 结束时间 |
| plannedSeconds | Int | 计划时长 |
| focusedSeconds | Int | 实际专注时长 |
| completed | Boolean | 是否完整完成 |

**规则**：
- `minimumRecordedSeconds = 60`：少于 60 秒的专注不记录
- `isRecordable`：`focusedSeconds >= 60`
- `isCompletedPomodoro`：`completed && isRecordable`
- `dayKey`：按 `endedAt` 本地时间生成 `YYYY-MM-DD` 字符串

### 3.4 TimerSnapshot — 定时器快照

| 字段 | 类型 | 说明 |
|------|------|------|
| mode | TimerMode | 当前模式 |
| phase | TimerPhase | 当前阶段 |
| totalSeconds | Int | 总时长 |
| remainingSeconds | Int | 剩余秒数 |
| completedFocusCycles | Int | 已完成专注轮数 |
| startedAt | DateTime? | 开始时间 |
| endsAt | DateTime? | 预计结束时间 |
| pausedAt | DateTime? | 暂停时间 |

**关键逻辑**：剩余时间通过 `endsAt` 时间戳差计算，而非计数器递减。保证暂停/恢复的精确性。

### 3.5 TomatoData — 完整应用状态

| 字段 | 类型 | 说明 |
|------|------|------|
| settings | AppSettings | 用户设置 |
| sessions | List\<FocusSession\> | 专注记录列表 |
| timer | TimerSnapshot | 当前定时器状态 |
| focusCycleCount | Int | 累计完成番茄数 |
| updatedAt | DateTime | 最后更新时间 |

**聚合方法**：
- `totalFocusSeconds`：所有 `isRecordable` 会话的 `focusedSeconds` 总和
- `focusSecondsByDay()`：按日聚合的 `Map<dayKey, totalSeconds>`

**持久化格式**：JSON，含 `schemaVersion` 字段（当前版本 1），支持向前迁移。

---

## 四、计时引擎 (TomatoTimerEngine)

### 4.1 设计原则
- 纯函数：所有方法 `const`，输入 `TomatoData`，输出 `TomatoData` 或 `TimerTickResult`
- 无 I/O、无副作用、无平台依赖
- 时间参数可注入（`{DateTime? at}`），便于测试

### 4.2 方法签名

| 方法 | 输入 | 输出 | 说明 |
|------|------|------|------|
| `snapshotForMode(mode, settings)` | TimerMode, AppSettings | TimerSnapshot | 创建指定模式的 idle 快照 |
| `start(data, at?)` | TomatoData | TomatoData | 启动/恢复计时 |
| `pause(data, at?)` | TomatoData | TomatoData | 暂停运行中的计时 |
| `reset(data, at?)` | TomatoData | TomatoData | 重置为专注 idle |
| `stop(data, at?)` | TomatoData | TomatoData | 停止计时，记录未完成专注 |
| `skip(data, at?)` | TomatoData | TomatoData | 跳过运行中的休息 |
| `selectMode(data, mode, at?)` | TomatoData, TimerMode | TomatoData | 切换到指定模式 |
| `tick(data, at?)` | TomatoData | TimerTickResult | 每秒递减，到期自动转换 |
| `applySettings(data, settings, at?)` | TomatoData, AppSettings | TomatoData | 应用新设置 |

### 4.3 阶段转换逻辑

```
focus 完成 → (cycleCount < limit) → shortBreak/longBreak (running)
           → (cycleCount >= limit) → focus idle (停止)

break 完成 → (cycleCount < limit) → focus (running)
           → (cycleCount >= limit) → focus idle (停止)

skip  → 仅允许跳过运行中的休息
      → 不允许跳过正在进行的专注
      → 跳过后进入 running 专注

stop  → 当前专注 >= 60s → 写入 completed=false 记录
      → 当前专注 < 60s → 不记录
      → 始终回到 focus idle
```

### 4.4 关键边界条件
- 暂停后 `start()` 从暂停处继续
- `endsAt` 计算基于 `DateTime.now().add(Duration(seconds: remaining))`
- `_remainingSeconds()` 使用毫秒级精度 `ceil()`，确保 `max(0, min(remaining, total))`
- `tick()` 在 `remaining == current.remainingSeconds` 时不触发更新（性能优化）

---

## 五、AppController (状态编排)

### 5.1 职责
- 持有 `TomatoData` 单一状态源
- `Timer.periodic` 驱动每秒 `tick()`
- 串联 `TimerEngine` → `AppStorage` → `CompletionFeedback`
- 管理消息队列（用于 SnackBar 展示）
- 管理本地自动备份定时器

### 5.2 关键实现

```kotlin
// 数据流转方法
fun start()
fun pause()
fun reset()
fun stop()
fun skip()
fun selectMode(mode: TimerMode)
fun updateSettings(settings: AppSettings)
fun createLocalBackup(directory: String?)
fun restoreFromLocalJson(rawJson: String)

// 内部方法
private fun _tick()    // 每秒由 Timer.periodic 调用
private fun _replaceData(next: TomatoData)  // 更新 + 自动保存
private fun _saveData(snapshot: TomatoData) // 队列防并发写入
private fun _notify()  // UI 通知
```

### 5.3 消息队列
- `_message: String?` 通过 `takeMessage()` 消费
- 特殊 token：`LOCAL_BACKUP_SUCCESS`、`LOCAL_RESTORE_SUCCESS` → 触发弹窗
- 其他消息 → SnackBar

### 5.4 保存防并发
- `_saveQueue` 链式 Promise 串联
- 每次保存等前一次完成后执行
- 错误只通知一次（`_saveErrorNotified` 防重复）

---

## 六、数据存储 (AppStorage)

### 6.1 文件结构
```
{data_directory}/
  tomato_data.json          ← 主数据文件
  local_backups/            ← 备份目录
    gan_backup_20260707_120000.json
    gan_backup_20260707_130000.json
```

### 6.2 数据目录发现顺序
1. `TOMATO_CLOCK_HOME` 环境变量
2. `HOME` / `USERPROFILE` 环境变量
3. 系统临时目录
4. 当前工作目录

### 6.3 原子写入策略
1. 写入 `tomato_data.json.tmp`
2. 如原文件存在则删除
3. `rename` tmp 文件 → 正式文件
4. 确保写入中断不会损坏现有数据

### 6.4 备份规则
- 文件名：`gan_backup_YYYYMMDD_HHMMSS.json`
- 备份文件存在时添加后缀（`_1`, `_2`）
- `_pruneBackups()` 删除超出 `keepCount` 的旧备份
- 支持 Android SAF `content://` URI

---

## 七、平台桥接

### 7.1 Android (Java) — MainActivity.java

#### MethodChannel 方法清单

| 方法 | 参数 | 功能 |
|------|------|------|
| setKeepScreenOn | enabled: Boolean | 窗口 FLAG_KEEP_SCREEN_ON |
| setPipState | enabled, title, subtitle, keepScreenOn, totalSeconds, remainingSeconds | 更新 PiP 参数 |
| enterPictureInPicture | - | 主动进入 PiP |
| setTimerNotification | enabled, title, subtitle, totalSeconds, remainingSeconds | 进度通知（仅提醒一次，静默） |
| showStageNotification | title, subtitle | 阶段变更通知 |
| requestNotificationPermission | - | Android 13+ 通知权限 |
| openNotificationSettings | - | 系统通知设置 |
| requestLocationPermission | - | ACCESS_FINE_LOCATION |
| openLocationSettings | - | 系统定位设置 |
| playCompletionSound | - | 系统通知音 |
| pickDirectory | - | SAF 目录选择 |
| pickBackupFile | - | SAF 文件选择（application/json） |
| readTextFile | fileUri: String | SAF 文件读取 |
| writeTextFile | directoryUri, displayName, contents | SAF 文件写入 |
| vibrate | durationMs, amplitude | 震动 |
| vibratePattern | timingsMs, amplitudes | 震动模式 |

#### 原生回调

| 回调 | 触发时机 |
|------|----------|
| onPictureInPictureModeChanged | PiP 进入/退出 |
| onKeepScreenOnChanged | 系统常亮状态变化 |

#### Android 特有配置
- PiP 比例：`9:16`，居中 `sourceRectHint`（44% 宽高）
- SDK 31+：`setAutoEnterEnabled(true)`, `setSeamlessResizeEnabled(true)`
- 通知：`NotificationCompat` + `PRIORITY_LOW` + `setOnlyAlertOnce(true)` + `setSilent(true)`
- 通知进度：`setProgress(total, elapsed, false)`
- 权限：`POST_NOTIFICATIONS` (13+), `ACCESS_FINE_LOCATION`

### 7.2 Linux (C++) — my_application.cc

| 功能 | 实现方式 |
|------|----------|
| 系统托盘 | libappindicator，动态倒计时标签 |
| 桌面通知 | D-Bus `org.freedesktop.Notifications`，KDE hint |
| 屏幕常亮 | GTK inhibit + D-Bus ScreenSaver + PowerManagement |
| 文件选择 | GtkFileChooserNative |
| 文件 I/O | GIO/GFile |
| 窗口行为 | 关闭 → 隐藏（最小化到托盘）vs 退出 |

---

## 八、UI 架构

### 8.1 页面结构

```
TimerPage (主计时页)
  ├── _AmbientInfoLine      ── 顶部：时钟 + 天气（30 分钟轮询）
  ├── _HitokotoLine         ── 一言引用（应用进程内缓存）
  ├── TimerProgressRing     ── 计时圆环（CustomPaint）
  ├── _PhasePill            ── 阶段胶囊
  └── TimerActions          ── 操作按钮行

StatsPage (统计页)
  ├── _TodayStats           ── 今日/总专注统计卡片
  ├── FocusHeatmap          ── 热力图（月/年视图）
  └── _RecentSessions       ── 最近记录列表

SettingsPage (设置页)
  └── 5 个子页面：计时与待机 / 切换提醒 / 外观 / 备份 / 天气
```

### 8.2 计时圆环 (TimerProgressRing)
- 使用 `CustomPaint` + `_RingPainter` 绘制圆弧进度
- 启动动效：脉冲缩放 (1→1.028→1) + 光晕淡入淡出
- 进度变化：`easeOutCubic` 补间（680ms 运行态，320ms 空闲态）
- 中心内容：模式图标 + 倒计时文本 + 阶段标签
- PiP 模式：紧凑布局，仅保留圆环 + 数字

### 8.3 热力图 (FocusHeatmap)
- 月视图：7 列网格，以周为行，显示日期数字
- 年视图：紧凑布局，12px 方块，横向滚动，星期/月标记
- 点击选中日期 → 显示当天专注时长
- 宽屏侧栏展示摘要，窄屏在热力图上方
- GitHub 风格 5 级配色（亮/暗各一套）

### 8.4 纯净模式 & OLED 模式
```
无操作 → idleFocusSeconds 秒 → 纯净模式（隐藏 UI）
       → 再 idleFocusSeconds 秒 → OLED 模式（纯黑背景）
触摸/点击 → 恢复完整 UI
```

---

## 九、外部服务

### 9.1 天气 (WeatherService)
- 定位链：手动城市 > IP 定位缓存
- IP 定位：ipapi.co → 回退 ip-api.com
- 逆地理编码：nominatim.openstreetmap.org（获取区级名称）
- 天气数据：api.open-meteo.com（温度 + WMO 天气代码）
- 超时：4 秒，所有失败静默返回 null
- 中文天气标签映射（晴/少云/多云/雾/毛毛雨/雨/雪/阵雨/阵雪/雷雨）

### 9.2 一言 (HitokotoService)
- 端点：`v1.hitokoto.cn/?encode=json&max_length=28`
- 超时：1.8 秒，失败静默
- 截断规则：超过 40 字符拒绝
- 应用进程内缓存，启动时加载一次
- 本地兜底：专注/短休息/长休息各 4 句，按日期轮换

---

## 十、阶段配色

| 模式 | 强调色 | 浅色背景 | 深色背景 |
|------|--------|----------|----------|
| 专注 | `#B15E52` 红褐 | `#EFEAEC` | `#171416` |
| 短休息 | `#3D8A5D` 绿 | `#E9EFEB` | `#141916` |
| 长休息 | `#3D79A8` 蓝 | `#E8ECF2` | `#14191E` |

全局 Material 3 主题种子：`#646464`（灰色）

---

## 十一、测试策略

| 测试文件 | 覆盖内容 |
|----------|----------|
| timer_engine_test.dart | 启动/暂停/恢复/停止/跳过、阶段转换、60s 阈值、循环限制 |
| models_test.dart | JSON 序列化往返、schema 迁移、边界值 clamp、旧版兼容 |
| app_controller_test.dart | 过期 tick、本地备份、消息队列、完成反馈 |
| hitokoto_service_test.dart | JSON 解析、长度校验 |
| widget_test.dart | 初始状态、按钮行为、主题切换、纯净模式、热力图、PiP |

---

## 十二、Flutter → Kotlin 迁移要点

### 12.1 替代映射

| Flutter | Android/Kotlin |
|---------|---------------|
| ChangeNotifier | ViewModel + StateFlow |
| InheritedNotifier | Hilt/Manual DI |
| dart:convert JSON | kotlinx.serialization / Gson |
| dart:io File | java.io.File |
| Timer.periodic | Handler / Coroutine delay |
| CustomPaint | Canvas + Paint in custom View |
| AnimatedContainer | ValueAnimator / Compose animation |
| MethodChannel | 移除，改为直接调用 |

### 12.2 工程结构建议
```
app/src/main/java/com/wucai/tomato_clock/
  domain/
    engine/TomatoTimerEngine.kt
    model/{TimerMode, TimerPhase, AppSettings, FocusSession, TimerSnapshot, TomatoData}.kt
  data/
    storage/AppStorage.kt
    service/{WeatherService, HitokotoService}.kt
  ui/
    timer/
    stats/
    settings/
    components/{TimerRing, Heatmap, ChromeFade, ActionButtons}.kt
  bridge/
    PlatformControls.kt (直接调用系统 API，不再需要 MethodChannel)
```

### 12.3 需要保留的特性清单
- [ ] 纯函数计时引擎，便于单元测试
- [ ] 原子 JSON 文件写入
- [ ] 本地备份/恢复（含 SAF 支持）
- [ ] PiP 9:16 画中画
- [ ] 屏幕常亮
- [ ] 通知（含进度条、仅提醒一次）
- [ ] 震动模式（双脉冲/长振/三段式）
- [ ] 完成提示音
- [ ] 天气显示（Open-Meteo）
- [ ] 一言（hitokoto.cn）
- [ ] GitHub 风格热力图（月/年）
- [ ] 纯净模式 + OLED 模式
- [ ] 主题 3 档（系统/浅色/深色）
- [ ] 阶段配色
- [ ] 循环控制（轮数/长休间隔）
- [ ] 60 秒阈值过滤

### 12.4 可移除的 Flutter 特性
- [x] Material Design 3 主题系统（用 Compose MD3 或原生主题替代）
- [x] Linux/Fedora KDE 桥接（非 Android 目标）
- [x] MethodChannel 框架（直接调用系统 API）
- [x] dart:io 文件系统（用 java.io 替代）

---

## 十三、架构决策记录

| 决策 | 理由 |
|------|------|
| 纯函数引擎 | 可测试、可推理、无副作用 |
| 原子文件写入 | 防崩溃损坏 |
| 时间戳计时 | 精确的暂停/恢复 |
| 零第三方依赖 | 可控、安全、无漏洞面 |
| 消息队列 | UI 与 Controller 解耦 |
| 保存防并发队列 | 防止多定时器竞争写入 |
