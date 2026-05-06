# 架构说明

## 技术栈

- Flutter + Dart
- Material 3
- ChangeNotifier
- 本地 JSON 存储
- WebDAV 同步

## 分层

1. UI 层（`main.dart`、`heatmap.dart`）
2. 状态与编排层（`app_controller.dart`）
3. 领域逻辑层（`timer_engine.dart`）
4. 数据模型层（`models.dart`）
5. 基础设施层（`storage.dart`、`webdav_service.dart`）
6. 平台桥接层（`platform_controls.dart` + `android/MainActivity.java`）

## 设计原则

- 业务逻辑优先放在 Dart
- Android 宿主仅负责系统能力接入
- 数据可恢复、可备份、可合并
- 以测试保障计时与同步逻辑
