# TomatoClock 开发进度

## 项目概述

跨平台番茄钟，Flutter + Dart，Material Design 3，轻量低功耗。

**当前阶段:** 番茄钟主流程已完成，主界面改为沉浸式计时、浮动 dock、阶段背景提示，并加入画中画、屏幕常亮和热力图选日。

## 完成

### 数据层
- [x] 数据模型 — `TimerMode`, `TimerPhase`, `AppSettings`, `WebDavSettings`, `FocusSession`, `TimerSnapshot`, `TomatoData`
- [x] JSON 序列化/反序列化
- [x] 数据合并逻辑 (`mergeWith`) — 处理多端同步冲突
- [x] 计时状态推进逻辑 (`timer_engine.dart`) — 启动、暂停、重置、跳过、完成结算
- [x] 有效专注过滤 — 少于 1 分钟的专注不进入记录、统计或热力图
- [x] 停止记录 — 停止专注时满 1 分钟会记录专注时长，但不计为完成番茄

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
- [x] 设置分条目 — 计时设置、外观、切换提醒、WebDAV 同步独立配置
- [x] 沉浸式主界面 — 移除顶部大标题，底部导航改为悬浮 dock

### 动效
- [x] 番茄钟启动动效 — 圆环局部脉冲、缓出进度补间、阶段文字淡切
- [x] 闲置静默显示 — 运行中无操作或点击空白区域后淡出导航和操作区，仅保留同位置番茄钟
- [x] 阶段背景动画 — 专注、短休息、长休息用背景色渐变提示当前阶段

### 平台脚手架
- [x] Android / iOS / Linux / macOS / Windows 平台目录就绪
- [x] Android 入口改为 Java `MainActivity`，保留 FlutterActivity 嵌入并接入画中画/屏幕常亮
- [x] Android Gradle 脚本改为 Groovy，移除 Kotlin DSL 和 Kotlin 插件
- [x] Android 自绘矢量图标 — 亮色/夜间自适应圆环时钟图标

## 待开发

### 核心功能
- [x] `main.dart` — 应用入口，MaterialApp + 主题
- [x] 状态管理 — 轻量 ChangeNotifier + InheritedNotifier
- [x] 计时引擎 — 纯 Dart，跨平台复用
- [x] 主计时页面 — 圆环进度、开始/暂停/跳过按钮
- [x] 停止当前计时 — 运行或暂停时可直接停止并回到当前模式初始时间
- [x] 一言展示 — 番茄钟下方显示随阶段切换的本地短句
- [x] 模式切换 — 专注 / 短休息 / 长休息
- [x] 计时完成通知/震动

### 原生层清理
- [x] 计时逻辑从 Kotlin 移入 Dart
- [x] 删除 Kotlin 悬浮窗服务与 MethodChannel 桥接
- [x] 删除 Android 悬浮窗权限、前台服务权限和服务声明

### 统计
- [x] 今日统计卡片 — 完成番茄数、总专注时长
- [x] 热力图组件 — 月/年切换、点击日期查看当天专注时间
- [x] 总专注时长展示

### 设置
- [x] 自定义时长 — 专注/短休/长休/长休间隔
- [x] 静默显示时间 — 可设置多久无操作后进入仅保留番茄钟的界面
- [x] 外观模式 — 跟随系统 / 浅色 / 夜间
- [x] 屏幕常亮 — 计时页快捷按钮控制 Android 屏幕常亮
- [x] WebDAV 配置界面
- [x] 手动同步按钮
- [x] 切换震动/音效开关

### 跨平台适配
- [x] Android 画中画 — 运行中回到后台或点击画中画按钮进入 PiP
- [ ] iOS 后台计时 (BGTaskScheduler)
- [ ] 桌面端迷你窗口方案
- [ ] 各平台通知适配

### 工程
- [ ] 应用图标
- [x] 测试用例 — Widget smoke test + 计时引擎/控制器单测
- [x] 性能优化 — 热力图 RepaintBoundary，原生桥接移除后减少平台调用

## 开发日志

### 2026-05-06 沉浸计时与 Android 画中画
- 修复停止后专注时间不统计的问题：停止专注时满 60 秒会写入 `FocusSession`，计入专注时长、热力图和最近记录，但 `completed=false`，不算完成番茄。
- 主计时页移除顶部 AppBar 和手动阶段切换，使用全屏阶段背景色提示专注、短休息、长休息。
- 计时器固定在屏幕中心，静默显示只对一言、状态胶囊、操作区和悬浮 dock 做淡出/滑出动画，计时器位置不再跳变。
- 支持点击计时页空白区域立即进入静默显示，触摸计时器区域恢复控件。
- 操作区增加屏幕常亮和画中画按钮，开始和停止加入触感反馈，并配合既有圆环启动动效。
- Android 增加 Java `MainActivity`，通过轻量 MethodChannel 控制屏幕常亮、PiP 状态和后台自动进入画中画；不引入 Kotlin。
- 新增亮色/夜间自适应矢量启动图标，元素为简洁圆环时钟。

### 2026-05-06 主题跟随系统与热力图选日
- 外观设置从布尔夜间模式升级为 `AppThemeMode`，支持“跟随系统 / 浅色 / 夜间”三档，并兼容旧的 `darkModeEnabled` 本地数据。
- `MaterialApp.themeMode` 改为根据外观设置映射到 `ThemeMode.system/light/dark`。
- 热力图日期块增加点击选中状态，月视图和年视图都可以切换选中日期，下方显示该天专注时间。
- 补充 Widget 测试，覆盖三档主题切换和点击热力图日期后的当天专注时间展示。

### 2026-05-06 夜间模式与记录阈值
- 新增夜间主题和“外观”设置条目，支持手动切换深色界面。
- Material 主题拆分为亮色/深色两套，计时器文字、圆环轨道、统计卡片和热力图颜色改为跟随 `ColorScheme`。
- `FocusSession` 增加 60 秒有效记录阈值，少于 1 分钟的专注结束后不写入记录，也不计入今日统计、总时长、热力图或最近专注。
- 补充单元测试和 Widget 测试，覆盖夜间模式序列化/切换，以及短于 1 分钟记录的过滤。

### 2026-05-06 番茄钟静默模式
- 主计时页增加停止键，停止当前运行或暂停的计时后回到当前阶段的初始时长，不写入完成记录。
- 番茄钟圆环下方增加本地“一言”，按专注、短休息、长休息显示不同短句，不依赖网络请求。
- 新增 `idleFocusSeconds` 设置，运行中超过设定秒数无操作后隐藏顶部栏、底部导航、模式切换和操作按钮，仅保留番茄钟；点击或触摸后恢复完整界面。
- 补充计时引擎与 Widget 测试，覆盖停止键、静默显示和设置序列化。

### 2026-05-06 启动动效优化
- `TimerProgressRing` 改为局部 Stateful 动画，启动时只对计时器圆环做轻微缩放和光晕脉冲。
- 圆环进度从线性跳变改为 `easeOutCubic` 补间，减少每秒 tick 的生硬感。
- 模式图标和阶段文字使用短时 `AnimatedSwitcher` 淡切，避免整页一起动。

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
| 平台入口 | Android Java MainActivity + FlutterActivity，计时业务保持 Dart，无 Kotlin |
| UI | Material Design 3 |
