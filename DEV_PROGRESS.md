# TomatoClock 开发进度

## 项目概述

跨平台番茄钟，Flutter + Dart，Material Design 3，轻量低功耗。

**当前阶段:** 主计时闭环已完成，下一步聚焦通知/音效、悬浮窗瘦身与统计深化。

## 完成

### 数据层
- [x] 数据模型 — `TimerMode`, `TimerPhase`, `AppSettings`, `WebDavSettings`, `FocusSession`, `TimerSnapshot`, `TomatoData`
- [x] JSON 序列化/反序列化
- [x] 数据合并逻辑 (`mergeWith`) — 处理多端同步冲突
- [x] 计时状态推进逻辑 (`timer_engine.dart`) — 启动、暂停、重置、跳过、完成结算

### 本地持久化
- [x] 原子写入存储 (`storage.dart`) — tmp 文件 + rename 策略
- [x] 自动创建数据目录
- [x] 存储接口抽象 (`TomatoStore`) — 便于控制器和测试注入

### WebDAV 同步
- [x] 上传/下载/同步 (`webdav_service.dart`)
- [x] Basic Auth 认证
- [x] 自动创建远端目录层级
- [x] TLS/网络错误处理

### Android 原生层
- [x] 悬浮窗前台服务 (`TomatoOverlayService.kt`) — 倒计时显示、拖拽移动、通知栏
- [x] MethodChannel 桥接 (`MainActivity.kt`)
- [x] SYSTEM_ALERT_WINDOW 权限处理
- [x] 前台服务通知渠道

### 平台脚手架
- [x] Android / iOS / Linux / macOS / Windows 平台目录就绪

## 待开发

### 核心功能
- [x] `main.dart` — 应用入口，MaterialApp + 主题
- [x] 状态管理 — 轻量 ChangeNotifier + InheritedNotifier
- [x] 计时引擎 — 纯 Dart，跨平台复用
- [x] 主计时页面 — 圆环进度、开始/暂停/跳过按钮
- [x] 模式切换 — 专注 / 短休息 / 长休息
- [ ] 计时完成通知/音效

### 悬浮窗
- [ ] 计时逻辑从 Kotlin 移入 Dart
- [ ] Kotlin 服务瘦身 — 仅保留 UI 壳

### 统计
- [x] 今日统计卡片 — 完成番茄数、总专注时长
- [ ] 热力图组件 — 月/年切换
- [x] 总专注时长展示

### 设置
- [x] 自定义时长 — 专注/短休/长休/长休间隔
- [x] 悬浮窗开关
- [x] WebDAV 配置界面
- [x] 手动同步按钮

### 跨平台适配
- [ ] iOS 后台计时 (BGTaskScheduler)
- [ ] 桌面端悬浮窗方案 (始终置顶小窗)
- [ ] 各平台通知适配

### 工程
- [ ] 应用图标
- [x] 测试用例 — Widget smoke test + 计时引擎单测
- [ ] 性能优化 — 减少不必要的 rebuild

## 开发日志

### 2026-05-06
- 新增纯 Dart `TomatoTimerEngine`，负责计时启动、暂停、重置、跳过、完成后自动进入下一阶段，并在专注完成时写入 `FocusSession`。
- 新增 `AppController`，用 `ChangeNotifier` 串联本地存储、WebDAV、悬浮窗桥接和计时器 tick。
- 新增 Material 3 主界面，包含模式切换、圆环进度、开始/暂停/重置/跳过、今日统计、最近记录和设置面板。
- 设置面板支持自定义专注/休息时长、长休间隔、悬浮窗开关、WebDAV 配置保存和手动同步。
- 补充 Widget smoke test 与计时引擎单元测试。

## 技术栈

| 层 | 方案 |
|---|---|
| 框架 | Flutter 3.x, Dart 3.x |
| 状态管理 | ChangeNotifier (轻量，无额外依赖) |
| 持久化 | 本地 JSON 文件 + WebDAV 远端同步 |
| 悬浮窗 (Android) | Foreground Service + SYSTEM_ALERT_WINDOW |
| UI | Material Design 3 |
