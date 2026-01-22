# MindFlow 快速开始指南 ⚡

> 5 分钟快速启动 Flutter 项目

## 🎯 最简步骤

### macOS/Linux

```bash
# 1. 确保已安装 Flutter（如未安装，见下方）
flutter --version

# 2. 运行快速设置脚本
./setup.sh

# 3. 编辑环境变量
nano .env  # 填入豆包 API 密钥

# 4. 运行应用
flutter run
```

### Windows

```bat
# 1. 确保已安装 Flutter（如未安装，见下方）
flutter --version

# 2. 运行快速设置脚本
setup.bat

# 3. 编辑环境变量
notepad .env  # 填入豆包 API 密钥

# 4. 运行应用
flutter run
```

---

## 📦 Flutter 未安装？

### macOS (推荐使用 Homebrew)

```bash
brew install --cask flutter
```

或手动安装：

```bash
# 克隆 Flutter 仓库
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# 添加到 PATH
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 验证安装
flutter doctor
```

### Linux

```bash
# 下载 Flutter
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# 添加到 PATH
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 安装依赖
sudo apt-get install curl git unzip xz-utils zip libglu1-mesa

# 验证安装
flutter doctor
```

### Windows

1. 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. 解压到 `C:\flutter`
3. 添加 `C:\flutter\bin` 到系统环境变量 PATH
4. 打开新的命令提示符，运行 `flutter doctor`

---

## 🔑 获取豆包 API 密钥

1. 访问火山引擎控制台：https://console.volcengine.com/
2. 注册/登录账号
3. 前往「语音技术」或「智能语音」服务
4. 创建应用，获取：
   - App Key
   - Access Key
   - Resource ID
5. 前往「大模型服务」或「机器学习平台」
6. 获取 LLM API Key

---

## 🚀 运行应用

### 方式 1：命令行

```bash
# Debug 模式（支持热重载）
flutter run

# Release 模式（性能优化）
flutter run --release

# 指定设备
flutter run -d <device_id>

# 传递环境变量
flutter run --dart-define=DOUBAO_ASR_APP_KEY=xxx
```

### 方式 2：IDE

**VS Code:**
1. 安装 Flutter 和 Dart 扩展
2. 按 F5 启动调试
3. 选择目标设备

**Android Studio:**
1. 安装 Flutter 插件
2. 点击绿色运行按钮
3. 选择目标设备

---

## 📱 设备准备

### Android 设备

**模拟器：**
```bash
# 通过 Android Studio 创建 AVD
# 或使用命令行
flutter emulators
flutter emulators --launch <emulator_id>
```

**真机：**
1. 启用开发者选项（连续点击「版本号」7 次）
2. 启用 USB 调试
3. 连接电脑并授权
4. 运行 `flutter devices` 查看设备

### iOS 设备（仅 macOS）

**模拟器：**
```bash
open -a Simulator
# 或在 Xcode 中打开
```

**真机：**
1. 连接 iPhone/iPad
2. 在 Xcode 中配置签名（需要 Apple ID）
3. 信任开发者证书
4. 运行 `flutter devices` 查看设备

---

## 🐛 故障排除

### 问题 1：flutter 命令未找到

```bash
# 检查 Flutter 是否在 PATH 中
echo $PATH | grep flutter

# 重新添加到 PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### 问题 2：flutter doctor 显示错误

```bash
# 查看详细信息
flutter doctor -v

# 常见解决方案
flutter doctor --android-licenses  # 接受 Android 许可证
sudo xcode-select --switch /Applications/Xcode.app  # 配置 Xcode
```

### 问题 3：代码生成失败

```bash
# 清理并重新生成
flutter clean
rm -rf .dart_tool
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 问题 4：依赖冲突

```bash
# 更新依赖
flutter pub upgrade

# 强制重新获取
flutter pub cache clean
flutter pub get
```

---

## 📖 详细文档

- **完整设置指南**: [SETUP.md](SETUP.md)
- **项目架构**: [FLUTTER_ARCHITECTURE_PLAN.md](FLUTTER_ARCHITECTURE_PLAN.md)
- **项目说明**: [README.md](README.md)
- **PR 描述**: [PR_DESCRIPTION.md](PR_DESCRIPTION.md)

---

## ✨ 快速命令参考

```bash
# 项目设置
flutter create .                    # 生成平台代码
flutter pub get                     # 安装依赖
flutter pub run build_runner build  # 生成代码

# 开发
flutter run                         # 运行应用
flutter run -d <device>            # 指定设备
flutter devices                     # 查看设备
flutter logs                        # 查看日志

# 代码质量
flutter analyze                     # 静态分析
flutter test                        # 运行测试
flutter format .                    # 格式化代码

# 清理
flutter clean                       # 清理构建
flutter pub cache clean            # 清理缓存

# 构建
flutter build apk                   # 构建 Android APK
flutter build appbundle            # 构建 App Bundle
flutter build ios                   # 构建 iOS（macOS）
```

---

## 🎓 学习资源

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言教程](https://dart.dev/guides)
- [Flutter Codelabs](https://docs.flutter.dev/codelabs)
- [Flutter 中文网](https://flutter.cn/)

---

## 💡 提示

- 开发时使用 `flutter run --debug` 享受热重载
- 修改代码后按 `r` 热重载，按 `R` 完全重启
- 使用 `flutter pub run build_runner watch` 自动生成代码
- 使用 VS Code 或 Android Studio 的 Flutter 插件提升效率

---

**遇到问题？**
1. 检查 `flutter doctor` 输出
2. 查看 [SETUP.md](SETUP.md) 详细指南
3. 搜索错误信息
4. 查看 Flutter 官方文档

祝开发顺利！🚀
