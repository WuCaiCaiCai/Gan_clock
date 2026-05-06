# 开发与构建

## 环境要求

- Flutter 3.x
- Dart 3.11+
- Java 21
- Android SDK（minSdk 31）

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Android 打包

```bash
cd android
./gradlew assembleDebug
```

## 代码规范

- 提交前确保 `flutter analyze` 与 `flutter test` 通过
- 优先保持改动最小闭环
- 平台相关功能同时补充 Dart 层兜底逻辑
