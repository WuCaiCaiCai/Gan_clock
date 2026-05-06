# TomatoClock 开发进度

## 项目概述

跨平台番茄钟，Flutter + Dart，Material Design 3，轻量低功耗。

**当前阶段:** 纯 Dart 主功能闭环已完成；主界面已按番茄钟、统计、设置分层。

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

### 完成反馈
- [x] 阶段切换反馈 (`completion_feedback.dart`) — 默认手机震动，提示音可选
- [x] 切换反馈设置 — 震动/音效独立开关

### 信息架构
- [x] 一级界面拆分 — 番茄钟 / 统计 / 设置
- [x] 设置分条目 — 计时设置、切换提醒、WebDAV 同步独立配置

### 平台脚手架
- [x] Android / iOS / Linux / macOS / Windows 平台目录就绪
- [x] Android 入口改为 `io.flutter.embedding.android.FlutterActivity`
- [x] Android Gradle 脚本改为 Groovy，移除 Kotlin DSL 和 Kotlin 插件

## 待开发

### 核心功能
- [x] `main.dart` — 应用入口，MaterialApp + 主题
- [x] 状态管理 — 轻量 ChangeNotifier + InheritedNotifier
- [x] 计时引擎 — 纯 Dart，跨平台复用
- [x] 主计时页面 — 圆环进度、开始/暂停/跳过按钮
- [x] 模式切换 — 专注 / 短休息 / 长休息
- [x] 计时完成通知/震动

### 原生层清理
- [x] 计时逻辑从 Kotlin 移入 Dart
- [x] 删除 Kotlin 悬浮窗服务与 MethodChannel 桥接
- [x] 删除 Android 悬浮窗权限、前台服务权限和服务声明

### 统计
- [x] 今日统计卡片 — 完成番茄数、总专注时长
- [x] 热力图组件 — 月/年切换
- [x] 总专注时长展示

### 设置
- [x] 自定义时长 — 专注/短休/长休/长休间隔
- [x] WebDAV 配置界面
- [x] 手动同步按钮
- [x] 切换震动/音效开关

### 跨平台适配
- [ ] iOS 后台计时 (BGTaskScheduler)
- [ ] 桌面端迷你窗口方案
- [ ] 各平台通知适配

### 工程
- [ ] 应用图标
- [x] 测试用例 — Widget smoke test + 计时引擎/控制器单测
- [x] 性能优化 — 热力图 RepaintBoundary，原生桥接移除后减少平台调用

## 开发日志

### 2026-05-06 信息架构调整
- 主界面聚焦番茄钟本身，只保留模式切换、倒计时圆环和操作按钮。
- 统计信息移入独立“统计”页，包含今日统计、热力图和最近专注记录。
- 设置改为条目式入口，“计时设置 / 切换提醒 / WebDAV 同步”分别打开独立配置面板。

### 2026-05-06 震动提醒
- 阶段切换提醒改为手机震动优先：默认关闭提示音、开启震动。
- `completion_feedback.dart` 从 `HapticFeedback.mediumImpact()` 改为 `HapticFeedback.vibrate()`，更接近手机震动提醒。
- 设置页文案改为“切换震动 / 切换音效”，明确用于专注与休息阶段切换。

### 2026-05-06 纯 Dart 收尾
- 移除 Android Kotlin 源码：删除 `MainActivity.kt`、`TomatoOverlayService.kt`，Manifest 直接使用 Flutter `FlutterActivity`。
- 移除 Kotlin DSL：`settings.gradle.kts`、`build.gradle.kts`、`app/build.gradle.kts` 改为 Groovy Gradle 文件，删除 Kotlin Android 插件。
- 移除 Dart `MethodChannel` 桥接与悬浮窗开关，项目主业务代码保持纯 Dart。
- 新增 `completion_feedback.dart`，计时完成后根据设置播放系统提示音并触发触感反馈。
- 新增 `heatmap.dart`，支持月/年范围切换的专注热力图。
- 补充控制器测试，覆盖应用启动时对过期计时器的 Dart 侧结算与完成反馈触发。

### 2026-05-06 主计时闭环
- 新增纯 Dart `TomatoTimerEngine`，负责计时启动、暂停、重置、跳过、完成后自动进入下一阶段，并在专注完成时写入 `FocusSession`。
- 新增 `AppController`，用 `ChangeNotifier` 串联本地存储、WebDAV 和计时器 tick。
- 新增 Material 3 主界面，包含模式切换、圆环进度、开始/暂停/重置/跳过、今日统计、最近记录和设置面板。
- 设置面板支持自定义专注/休息时长、长休间隔、WebDAV 配置保存和手动同步。
- 补充 Widget smoke test 与计时引擎单元测试。

## 技术栈

| 层 | 方案 |
|---|---|
| 框架 | Flutter 3.x, Dart 3.x |
| 状态管理 | ChangeNotifier (轻量，无额外依赖) |
| 持久化 | 本地 JSON 文件 + WebDAV 远端同步 |
| 平台入口 | FlutterActivity，无 Kotlin / MethodChannel |
| UI | Material Design 3 |
