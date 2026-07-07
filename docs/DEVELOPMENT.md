# 开发指南 (Kotlin 版)

> 本文档为 Kotlin 重写版提供开发规范和工作流指引。

---

## 环境要求

- Android Studio Ladybug+ / IntelliJ IDEA
- Kotlin 2.0+
- Android SDK 31+
- Gradle 8.x + Kotlin DSL
- JDK 17+

## 项目结构

```
app/src/main/java/com/wucai/tomato_clock/
├── domain/          # 纯 Kotlin 领域层（无 Android 依赖）
│   ├── engine/
│   │   └── TomatoTimerEngine.kt
│   └── model/
│       ├── AppSettings.kt
│       ├── FocusSession.kt
│       ├── TimerSnapshot.kt
│       └── TomatoData.kt
├── data/            # 数据层
│   ├── storage/
│   │   └── AppStorage.kt
│   └── service/
│       ├── WeatherService.kt
│       └── HitokotoService.kt
├── ui/              # UI 层（Jetpack Compose）
│   ├── timer/
│   │   ├── TimerPage.kt
│   │   └── TimerRing.kt
│   ├── stats/
│   │   ├── StatsPage.kt
│   │   └── Heatmap.kt
│   ├── settings/
│   │   └── SettingsPage.kt
│   └── components/
│       ├── ActionButtons.kt
│       └── ChromeFade.kt
├── viewmodel/
│   └── AppViewModel.kt
└── bridge/
    └── PlatformControls.kt
```

## 开发步骤

### 第一阶段：领域层
1. 数据模型（枚举 + data class + JSON 序列化）
2. 计时引擎纯函数（单元测试覆盖全部状态转换）
3. 数据存储（文件 I/O + 原子写入 + 备份管理）

### 第二阶段：ViewModel + 桥接
4. AppViewModel（StateFlow + 计时调度 + 持久化串联）
5. 系统桥接（PiP / 通知 / 常亮 / 震动 / 音效 / 文件选择）

### 第三阶段：UI
6. 计时页面（圆环 + 一言 + 天气 + 操作按钮）
7. 统计页面（热力图 + 统计卡片 + 最近记录）
8. 设置页面（5 个子页面）

## 核心设计要求

| 模块 | 要求 |
|------|------|
| 计时引擎 | 纯函数，无 Android 导入，`data class` 不可变 |
| 数据存储 | 原子写入（tmp + rename），SAF 兼容 |
| 状态管理 | ViewModel + StateFlow，单一状态源 |
| UI | Jetpack Compose，MD3 主题 |
| PiP | 9:16 比例，自适应 `sourceRectHint` |
| 通知 | `setOnlyAlertOnce(true)`，`setSilent(true)`，进度条 |
| 震动 | `VibrationEffect.createWaveform` 模式 |
| 热力图 | Compose Canvas 自绘，月/年视图 |
| 备份 | 本地 JSON 文件，自动清理旧备份 |
| 网络 | `HttpURLConnection` / OkHttp，超时 4s |
| 测试 | 引擎 + 存储 + ViewModel 全覆盖 |

## 构建命令

```bash
# Debug
./gradlew assembleDebug

# Release
./gradlew assembleRelease

# 测试
./gradlew test

# 安装
./gradlew installDebug
```

## 代码规范

- 领域层严禁导入 `android.*` 包
- ViewModel 中 `viewModelScope.launch` 管理协程
- 文件 I/O 使用 `kotlinx.coroutines.Dispatchers.IO`
- UI 事件通过 `Channel<UiEvent>` 单次消费
- 所有平台调用封装在 `PlatformControls` 单例中
- 提交前确保 `./gradlew test` 通过
