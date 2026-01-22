# MindFlow Flutter 项目设置指南

## 📋 前提条件

### 1. 安装 Flutter SDK

**macOS/Linux:**
```bash
# 下载 Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable

# 添加到 PATH（添加到 ~/.bashrc 或 ~/.zshrc）
export PATH="$PATH:`pwd`/flutter/bin"

# 验证安装
flutter doctor
```

**Windows:**
1. 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. 解压到合适的位置（如 C:\flutter）
3. 添加 `C:\flutter\bin` 到系统 PATH
4. 运行 `flutter doctor` 验证

### 2. 安装平台工具

**Android 开发:**
- Android Studio
- Android SDK
- Android Emulator 或真机

**iOS 开发（仅 macOS）:**
- Xcode（从 App Store 安装）
- CocoaPods: `sudo gem install cocoapods`
- iOS 模拟器或真机

---

## 🚀 项目设置步骤

### 第一步：生成平台代码

在项目根目录执行：

```bash
# 生成 Android/iOS 等平台代码
flutter create . --org com.mindflow.app --project-name mindflow

# 这会生成：
# - android/          (Android 项目)
# - ios/              (iOS 项目)
# - web/              (Web 项目 - 可选)
# - macos/            (macOS 项目 - 可选)
# - linux/            (Linux 项目 - 可选)
# - windows/          (Windows 项目 - 可选)
```

**重要提示**：
- `--org com.mindflow.app` 设置包名/Bundle ID
- `--project-name mindflow` 设置项目名称
- 如果不想生成某些平台，可以使用 `--platforms android,ios`

### 第二步：安装依赖

```bash
# 安装 Flutter 依赖
flutter pub get

# 如果之前已经运行过，清理后重新安装
flutter clean
flutter pub get
```

### 第三步：生成代码

项目使用了代码生成工具（Freezed, Hive, JSON Serializable），需要生成代码：

```bash
# 生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 或者使用 watch 模式（开发时推荐）
flutter pub run build_runner watch --delete-conflicting-outputs
```

**生成的文件**：
- `*.freezed.dart` - Freezed 不可变模型
- `*.g.dart` - Hive 适配器和 JSON 序列化

### 第四步：配置环境变量

创建 `.env` 文件（根目录）：

```env
# 豆包 API 配置
DOUBAO_ASR_APP_KEY=your_app_key_here
DOUBAO_ASR_ACCESS_KEY=your_access_key_here
DOUBAO_ASR_RESOURCE_ID=your_resource_id_here
DOUBAO_LLM_API_KEY=your_llm_api_key_here
```

### 第五步：配置权限

#### Android 权限

编辑 `android/app/src/main/AndroidManifest.xml`，添加：

```xml
<manifest>
    <!-- 添加权限 -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>

    <application>
        ...
    </application>
</manifest>
```

#### iOS 权限

编辑 `ios/Runner/Info.plist`，添加：

```xml
<dict>
    <!-- 添加权限描述 -->
    <key>NSMicrophoneUsageDescription</key>
    <string>我们需要使用麦克风来录制您的语音日记</string>

    <key>NSCameraUsageDescription</key>
    <string>我们需要使用相机来拍摄照片（可选）</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>我们需要访问相册来选择照片（可选）</string>
</dict>
```

### 第六步：运行应用

```bash
# 检查可用设备
flutter devices

# 运行应用（会自动选择设备）
flutter run

# 指定设备运行
flutter run -d <device_id>

# Debug 模式（热重载）
flutter run --debug

# Release 模式（性能测试）
flutter run --release

# 传递环境变量
flutter run --dart-define=DOUBAO_ASR_APP_KEY=xxx
```

---

## 🔧 常见问题

### 1. `flutter doctor` 显示问题

运行 `flutter doctor` 并根据提示解决问题：

```bash
flutter doctor -v
```

常见问题：
- ✗ Android SDK 未安装 → 安装 Android Studio
- ✗ Xcode 未安装 → 从 App Store 安装
- ✗ CocoaPods 未安装 → `sudo gem install cocoapods`

### 2. 代码生成失败

```bash
# 清理并重新生成
flutter clean
rm -rf .dart_tool
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Hive 类型冲突

确保 `@HiveType(typeId: X)` 的 ID 唯一：
- RecordModel: `typeId: 0`
- WeeklyInsightModel: `typeId: 1`
- 添加新模型时使用新的 typeId

### 4. 依赖冲突

```bash
# 更新依赖
flutter pub upgrade

# 查看过时的依赖
flutter pub outdated
```

### 5. 真机测试

**Android:**
1. 在手机上启用开发者选项
2. 启用 USB 调试
3. 连接电脑并授权
4. `flutter devices` 应该能看到设备

**iOS:**
1. 连接 iPhone/iPad
2. 在 Xcode 中配置签名（需要 Apple Developer 账号）
3. 信任开发者证书
4. `flutter devices` 应该能看到设备

---

## 📱 平台特定配置

### Android 配置

**应用图标**：
- 替换 `android/app/src/main/res/mipmap-*/ic_launcher.png`

**应用名称**：
- 编辑 `android/app/src/main/AndroidManifest.xml`

**包名**：
- `com.mindflow.app.mindflow`（已通过 --org 设置）

**最小 SDK 版本**：
- 编辑 `android/app/build.gradle`
- 设置 `minSdkVersion 21`（Android 5.0+）

### iOS 配置

**应用图标**：
- 使用 `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**应用名称**：
- 编辑 `ios/Runner/Info.plist` 中的 `CFBundleName`

**Bundle ID**：
- `com.mindflow.app.mindflow`（已通过 --org 设置）

**部署目标**：
- 编辑 `ios/Podfile`
- 设置 `platform :ios, '12.0'`

---

## 🎯 开发工作流

### 1. 日常开发

```bash
# 启动应用（热重载模式）
flutter run

# 代码修改后，按 'r' 重新加载，按 'R' 完全重启
```

### 2. 添加新功能

```bash
# 1. 修改代码
# 2. 如果修改了 Freezed/Hive 模型，重新生成
flutter pub run build_runner build --delete-conflicting-outputs

# 3. 热重载测试
```

### 3. 调试

```bash
# 查看日志
flutter logs

# 调试模式运行
flutter run --debug

# 使用 VS Code / Android Studio 的调试器
```

### 4. 性能分析

```bash
# Profile 模式（性能分析）
flutter run --profile

# 打开 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### 5. 构建发布版本

**Android APK:**
```bash
flutter build apk --release
# 输出：build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (推荐 Google Play):**
```bash
flutter build appbundle --release
# 输出：build/app/outputs/bundle/release/app-release.aab
```

**iOS (需要 macOS):**
```bash
flutter build ios --release
# 然后在 Xcode 中打开 ios/Runner.xcworkspace 进行归档
```

---

## 📚 学习资源

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言教程](https://dart.dev/guides)
- [BLoC 模式文档](https://bloclibrary.dev/)
- [Hive 数据库文档](https://docs.hivedb.dev/)
- [Flutter 中文网](https://flutter.cn/)

---

## ✅ 快速检查清单

开发前确认：

- [ ] Flutter SDK 已安装并在 PATH 中
- [ ] Android Studio 或 Xcode 已安装
- [ ] 运行 `flutter doctor` 没有错误
- [ ] 已执行 `flutter create .`
- [ ] 已执行 `flutter pub get`
- [ ] 已执行 `build_runner build`
- [ ] 已配置环境变量（.env）
- [ ] 已配置平台权限
- [ ] 可以成功运行 `flutter run`

---

如有问题，请查看：
- `flutter doctor -v` 的详细输出
- `flutter analyze` 的代码分析结果
- 项目的 README.md 文档

祝开发顺利！🎉
