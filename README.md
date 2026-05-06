# 苷

一个偏安静、偏手机使用场景的番茄钟。主流程用 Flutter 和 Dart 编写，提供阶段色计时圆环、沉浸式专注界面、统计热力图、WebDAV 备份和 Android 画中画。

当前项目准备上传 GitHub，暂不发布正式版本。

## 功能

- 番茄钟循环：专注、短休息、长休息自动衔接。
- 停止记录：专注超过 1 分钟后停止会计入专注时长，但不算完成番茄。
- 一言：接入官方一言接口，网络不可用时立即使用本地短句兜底。
- 沉浸模式：运行中可自动或点击空白区域隐藏操作区，只保留一言和计时圆环。
- 阶段配色：专注红褐、短休绿色、长休蓝色，背景和圆环同步变化。
- Android 画中画：后台运行时显示近方形圆环小窗。
- 统计：今日专注、总专注时长、月/年热力图、最近专注记录。
- 备份：设置内提供本地 JSON 备份和 WebDAV 同步，应用存活或画中画运行时可按间隔自动同步。
- 外观：跟随系统、浅色、夜间模式。

## 技术边界

应用的计时、记录、统计、同步合并、设置和 UI 逻辑都在 Dart 中实现。

Android 目录中保留了极少量 Java 代码，作用是把 Flutter 接不到的系统能力桥接出来，包括：

- Android Picture-in-Picture 参数和进入/退出状态回调。
- 屏幕常亮窗口标记。

这部分不是业务逻辑。没有 Kotlin，也没有 Kotlin Gradle DSL。继续保留 Java 是为了使用 Android 系统级画中画；如果完全移除原生桥接，就需要放弃自动 PiP 这类系统能力。

## 备份逻辑

WebDAV 同步会把本地 JSON 数据和远端 JSON 数据合并：

- 专注记录按 `id` 去重并按结束时间排序。
- 设置和活动计时器使用更新时间较新的版本。
- 远端文件不存在时会创建新备份。
- 远端目录不存在时会逐级创建。

自动同步目前是应用进程存活时的定时同步：应用在前台、后台仍未被系统挂起，或处于 Android 画中画时，会按设置间隔尝试同步。Android 在应用被系统完全挂起或杀死后继续定时联网，需要 WorkManager 一类原生后台任务；项目暂时不引入这部分，以保持实现轻量。

本地备份默认会在应用数据目录下创建 `local_backups/gan_backup_YYYYMMDD_HHMMSS.json`，也可以在设置里指定其他目录；内容和 WebDAV 备份使用同一份 JSON 结构。

## 开发

环境：

- Flutter 3.x
- Dart 3.x
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
2. 使用数据线连接电脑，手机上允许 USB 调试授权。
3. 在 Android Studio 顶部设备列表选择手机。
4. 点击 Run，或执行 `flutter run`。

如果安装卡在 `Installing build/app/outputs/flutter-apk/app-debug.apk...`，优先检查手机授权弹窗、数据线模式、旧版调试包是否需要先卸载，以及 `adb devices` 是否显示为 `device`。

## 目录

```text
lib/
  app_controller.dart      状态协调、自动同步、持久化
  timer_engine.dart        纯 Dart 计时状态机
  hitokoto_service.dart    一言接口请求和离线兜底解析
  webdav_service.dart      WebDAV 上传、下载、合并同步
  main.dart                Flutter UI
  models.dart              数据模型和 JSON 序列化
test/                      单元测试和 Widget 测试
android/                   Android 宿主工程和最小系统桥接
assets/fonts/              霞鹜文楷字体资源
```

## 开源协议

MIT License。详见 [LICENSE](LICENSE)。
