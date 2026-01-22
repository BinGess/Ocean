# iOS 权限配置指南

## 问题说明

您的应用崩溃是因为使用了以下需要原生权限的包：
- `record` (麦克风录音)
- `permission_handler` (权限管理)
- `audioplayers` (音频播放)

但 iOS 的 `Info.plist` 文件中缺少必要的权限描述。

---

## 修复步骤

### 1. 编辑 Info.plist 文件

打开 `ios/Runner/Info.plist` 文件，在 `</dict>` 标签前添加以下内容：

```xml
<!-- 麦克风权限 - 用于录音功能 -->
<key>NSMicrophoneUsageDescription</key>
<string>MindFlow 需要访问麦克风来录制您的语音笔记</string>

<!-- 语音识别权限 - 用于语音转文字 -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>MindFlow 需要使用语音识别功能将录音转换为文字</string>

<!-- 后台音频权限 - 用于后台播放录音 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- 媒体库权限 - 用于保存和访问音频文件 -->
<key>NSAppleMusicUsageDescription</key>
<string>MindFlow 需要访问媒体库来保存您的录音</string>

<!-- App Transport Security 设置 - 允许 HTTP 请求（如果需要） -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### 2. 完整的 Info.plist 示例

如果您的 Info.plist 文件很简单，可以用以下完整版本替换：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>MindFlow</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>mindflow</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>

	<!-- ====== 权限配置 ====== -->

	<!-- 麦克风权限 -->
	<key>NSMicrophoneUsageDescription</key>
	<string>MindFlow 需要访问麦克风来录制您的语音笔记</string>

	<!-- 语音识别权限 -->
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>MindFlow 需要使用语音识别功能将录音转换为文字</string>

	<!-- 后台音频权限 -->
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
	</array>

	<!-- 媒体库权限 -->
	<key>NSAppleMusicUsageDescription</key>
	<string>MindFlow 需要访问媒体库来保存您的录音</string>

	<!-- App Transport Security -->
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<false/>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
</dict>
</plist>
```

### 3. 清理并重新构建

修改完成后，在项目根目录执行：

```bash
# 1. 清理构建缓存
flutter clean

# 2. 重新安装 CocoaPods 依赖
cd ios
rm -rf Pods/ Podfile.lock
pod install
cd ..

# 3. 重新获取依赖
flutter pub get

# 4. 重新运行应用
flutter run -d 7D86FBC8-B6D5-4FB2-9817-F1353DA12A6F
```

---

## 额外的 Podfile 配置

如果仍然有问题，可能需要更新 `ios/Podfile` 配置。

打开 `ios/Podfile`，确保有以下配置：

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # 添加权限相关的 Pod（如果需要）
  # pod 'Permission-Microphone', :path => ".symlinks/plugins/permission_handler/ios"
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # 设置最低 iOS 版本
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

---

## 故障排除

### 如果还是崩溃

1. **查看完整的崩溃日志**：
   ```bash
   flutter run -d 7D86FBC8-B6D5-4FB2-9817-F1353DA12A6F --verbose
   ```

2. **在 Xcode 中运行**以查看详细错误：
   ```bash
   open ios/Runner.xcworkspace
   ```
   然后在 Xcode 中点击 Run 按钮，查看控制台的详细错误信息。

3. **检查 CocoaPods 版本**：
   ```bash
   pod --version
   # 应该 >= 1.11.0
   ```

4. **检查 Xcode 版本**：
   ```bash
   xcodebuild -version
   # 应该 >= 14.0
   ```

### 常见错误

**错误：`Target native_assets required define SdkRoot`**
- 解决：这通常是 CocoaPods 依赖问题，执行上面的清理步骤即可

**错误：`Permission denied - microphone`**
- 解决：确保 Info.plist 中添加了 `NSMicrophoneUsageDescription`

**错误：`Module 'record' not found`**
- 解决：重新安装 CocoaPods 依赖（`cd ios && pod install`）

---

## 提交平台代码到 Git

修复完成后，建议将平台代码提交到 Git 仓库：

```bash
# 检查 .gitignore 是否忽略了平台目录
# 如果没有忽略，可以提交

git add ios/ android/
git commit -m "chore: 添加 iOS 和 Android 平台代码及权限配置"
git push origin claude/refactor-state-management-iMGmF
```

---

## 快速修复脚本

将以下内容保存为 `fix_ios_permissions.sh`，然后运行 `bash fix_ios_permissions.sh`：

```bash
#!/bin/bash

echo "🔧 修复 iOS 权限配置..."

# 备份原始文件
if [ -f "ios/Runner/Info.plist" ]; then
    cp ios/Runner/Info.plist ios/Runner/Info.plist.backup
    echo "✅ 已备份 Info.plist"
fi

# 检查文件是否存在
if [ ! -f "ios/Runner/Info.plist" ]; then
    echo "❌ 错误：ios/Runner/Info.plist 不存在"
    echo "请先运行 'flutter create .' 生成平台代码"
    exit 1
fi

# 添加权限配置（使用 PlistBuddy）
/usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'MindFlow 需要访问麦克风来录制您的语音笔记'" ios/Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription 'MindFlow 需要访问麦克风来录制您的语音笔记'" ios/Runner/Info.plist

/usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string 'MindFlow 需要使用语音识别功能将录音转换为文字'" ios/Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSSpeechRecognitionUsageDescription 'MindFlow 需要使用语音识别功能将录音转换为文字'" ios/Runner/Info.plist

echo "✅ 已添加权限描述"

# 清理并重新构建
echo "🧹 清理构建缓存..."
flutter clean

echo "📦 重新安装 CocoaPods..."
cd ios
rm -rf Pods/ Podfile.lock
pod install
cd ..

echo "📥 重新获取依赖..."
flutter pub get

echo "✅ 修复完成！现在可以运行 'flutter run'"
```

**使用方法**：
```bash
chmod +x fix_ios_permissions.sh
./fix_ios_permissions.sh
```
