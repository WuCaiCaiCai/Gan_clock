<div align="center">
  <img src="./icon.svg" width="96" height="96" alt="苷 icon">

  <h1>苷</h1>

  <p>一个安静、沉浸、偏手机使用场景的 Flutter 番茄钟。</p>

  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white">
    <img alt="Dart" src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white">
    <img alt="Material Design 3" src="https://img.shields.io/badge/Material%20Design%203-6750A4?logo=materialdesign&logoColor=white">
    <img alt="Android PiP" src="https://img.shields.io/badge/Android-Picture--in--Picture-3DDC84?logo=android&logoColor=white">
    <img alt="WebDAV" src="https://img.shields.io/badge/WebDAV-Backup-374151">
    <img alt="No Kotlin" src="https://img.shields.io/badge/Kotlin-0%20files-111827">
    <img alt="License MIT" src="https://img.shields.io/badge/License-MIT-black">
  </p>
</div>

## 项目状态

苷目前处于 GitHub 开源准备阶段，暂不发布正式版本。主目标是做好 Android 手机上的专注计时体验：打开应用是完整计时圆环，切到后台后进入 Android 画中画，统计和备份收在更低层级，避免把所有信息堆到一级界面。

计时、记录、统计、设置、WebDAV 合并同步和界面逻辑均使用 Dart 实现。Android 目录中仅保留少量 Java 作为系统能力桥接，用于 Picture-in-Picture 和屏幕常亮；项目没有 Kotlin，也没有 Kotlin Gradle DSL。

## 功能

| 模块 | 已实现能力 |
| --- | --- |
| 番茄钟 | 专注、短休息、长休息自动衔接；停止后回到新一轮专注；跳过只作用于运行中的休息 |
| 视觉 | 阶段色计时圆环；专注红褐、短休绿色、长休蓝色；跟随系统、浅色、夜间三种外观 |
| 沉浸 | 移除顶部大标题；底部悬浮 dock；运行中可自动或点击空白区域隐藏操作区 |
| 反馈 | 阶段切换、开始、停止使用手机震动优先；提示音可在设置中单独开启 |
| 一言 | 接入官方一言接口；无网、超时或返回异常时使用本地短句兜底；字体使用霞鹜文楷 |
| 画中画 | Android 后台自动进入 PiP；近方形圆环小窗；阶段颜色与主计时状态同步 |
| 统计 | 60 秒以下不计入记录；统计今日和总专注时长；月/年热力图支持点击日期查看当天专注 |
| 备份 | 设置内提供本地 JSON 备份和 WebDAV 同步；支持指定本地备份目录；应用存活期可定时自动同步 |

## 技术栈

| 方向 | 选型 | 说明 |
| --- | --- | --- |
| UI 框架 | Flutter | Material Design 3，面向手机比例重新组织主界面 |
| 语言 | Dart | 业务逻辑、计时状态机、同步合并、数据模型和 UI 全部在 Dart 层 |
| 状态管理 | ChangeNotifier | 保持轻量，不引入额外状态管理框架 |
| 数据存储 | 本地 JSON | 原子写入，启动时恢复计时器快照 |
| 远端同步 | WebDAV + dart:io | Basic Auth，自动创建远端目录，本地/远端 JSON 合并 |
| 平台能力 | Android Java bridge | 只桥接 PiP、屏幕常亮等 Flutter 不能直接覆盖的系统能力 |
| 测试 | flutter_test | 覆盖计时引擎、控制器、一言服务和关键 Widget 行为 |
| 构建 | Gradle Groovy + Java 21 | Android 工程移除 Kotlin/KTS，保留标准 Flutter 宿主结构 |

## 核心逻辑

### 计时与记录

- 计时状态由 `TomatoTimerEngine` 推进，专注完成后自动进入休息，休息结束后自动回到专注。
- 停止正在进行的专注时，如果已专注满 60 秒，会写入一条未完成记录并计入专注时间；不足 60 秒会直接丢弃。
- 完整完成的专注会计入番茄循环数，并按 `roundsBeforeLongBreak` 决定进入短休息或长休息。
- 跳过按钮只在休息阶段运行中可用，用于跳过休息并继续下一轮专注，不会打断正在进行的番茄钟。

### 备份与同步

- 本地备份会导出完整 JSON，默认写入应用数据目录下的 `local_backups/`，也可以在设置里指定目录。
- WebDAV 同步会先下载远端 JSON，再与本地数据合并，最后上传合并结果。
- 专注记录按 `id` 去重，设置和活动计时器保留更新时间较新的版本。
- 自动同步属于应用存活期定时任务：应用在前台、未被系统挂起的后台、或 Android PiP 中运行时，会按设置间隔尝试同步。

### 平台边界

项目追求“业务逻辑全 Dart”，但 Android PiP 和屏幕常亮是系统级能力，需要宿主层参与。因此 `MainActivity.java` 只做 Flutter 与 Android 系统 API 的桥接，不承载番茄钟业务规则。

## 运行

环境要求：

- Flutter 3.x
- Dart SDK `^3.11.5`
- Android 构建使用 Java 21

常用命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Android Studio 真机调试：

1. 手机开启开发者选项和 USB 调试。
2. 用数据线连接电脑，并在手机上允许 USB 调试授权。
3. 在 Android Studio 顶部设备列表选择手机。
4. 点击 Run，或在项目根目录执行 `flutter run`。

如果卡在 `Installing build/app/outputs/flutter-apk/app-debug.apk...`，优先检查手机授权弹窗、数据线模式、旧调试包是否需要卸载，以及 `adb devices` 是否显示为 `device`。

## 目录

```text
lib/
  app_controller.dart      状态协调、持久化、自动同步
  timer_engine.dart        纯 Dart 计时状态机
  hitokoto_service.dart    一言接口请求和本地兜底
  webdav_service.dart      WebDAV 上传、下载、合并同步
  heatmap.dart             专注热力图
  main.dart                Flutter UI
  models.dart              数据模型和 JSON 序列化
  storage.dart             原子写入和本地备份
android/
  app/src/main/java/...    Android PiP 和屏幕常亮桥接
assets/fonts/              霞鹜文楷字体资源
test/                      单元测试和 Widget 测试
```

## 开源协议

本项目使用 MIT License。详见 [LICENSE](LICENSE)。
