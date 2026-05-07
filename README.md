<div align="center">
  <img src="./icon.svg" width="96" height="96" alt="苷 icon" />
  <h1>苷 · Gan Clock</h1>
  <p>面向手机专注场景的 Flutter 番茄钟。</p>
  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" />
    <img alt="Dart" src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white" />
    <img alt="Android" src="https://img.shields.io/badge/Android-12%2B-3DDC84?logo=android&logoColor=white" />
    <img alt="Fedora KDE" src="https://img.shields.io/badge/Fedora%20KDE-Linux-51A2DA?logo=fedora&logoColor=white" />
    <img alt="License" src="https://img.shields.io/badge/License-MIT-black" />
  </p>
</div>

## 概述

苷是一个强调沉浸计时体验的番茄钟应用，核心目标是：

- 打开即用的专注计时主界面
- 清晰的统计与热力图反馈
- 稳定的数据持久化与备份同步
- 面向 Android 与 Linux/Fedora KDE 的系统能力适配（如 PiP、通知）

## 功能亮点

- 三阶段番茄流程：专注 / 短休息 / 长休息
- 可配置循环次数，到达上限自动停止
- 统计页与 GitHub 风格热力图
- 本地 JSON 备份 + WebDAV 同步
- Android 通知、画中画、震动反馈
- Linux/Fedora KDE 桌面通知与本地同步文件选择
- 明暗主题与灰色基调界面

## 快速开始

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## 文档

详细说明已迁移至 `docs/`：

- [文档索引](docs/README.md)
- [架构说明](docs/ARCHITECTURE.md)
- [开发与构建](docs/DEVELOPMENT.md)
- [开发进度记录](DEV_PROGRESS.md)

## 项目结构

```text
lib/       Flutter UI、状态管理、计时引擎、同步逻辑
android/   Android 宿主与系统能力桥接
linux/     Linux GTK runner 与 KDE/Freedesktop 通知桥接
test/      单元测试与 Widget 测试
docs/      项目文档
```

## License

MIT License · 详见 [LICENSE](LICENSE)
