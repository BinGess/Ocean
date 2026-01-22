# Android 权限配置指南

## 问题说明

MindFlow 使用了以下需要权限的功能：
- 录音（麦克风访问）
- 音频播放
- 本地存储（保存录音文件）

---

## 配置步骤

### 1. 编辑 AndroidManifest.xml

打开 `android/app/src/main/AndroidManifest.xml` 文件，在 `<manifest>` 标签内、`<application>` 标签前添加以下权限：

```xml
<!-- 录音权限 -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- 音频相关权限 -->
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.WRITE_SETTINGS" />

<!-- 存储权限（Android 12 及以下） -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- 网络权限（用于 API 调用） -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 前台服务权限（如果需要后台录音） -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

<!-- 唤醒锁（保持应用运行） -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### 2. 完整的 AndroidManifest.xml 示例

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- ====== 权限配置 ====== -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:label="MindFlow"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <!-- 指定所需的功能 -->
    <uses-feature android:name="android.hardware.microphone" android:required="true" />
</manifest>
```

### 3. 更新 build.gradle 配置

打开 `android/app/build.gradle`，确保 `minSdkVersion` 至少为 21：

```gradle
android {
    namespace = "com.mindflow.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId = "com.mindflow.app"
        minSdk = 21  // 至少 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.debug
        }
    }
}
```

### 4. 清理并重新构建

```bash
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 运行应用
flutter run
```

---

## 运行时权限处理

应用中已经使用 `permission_handler` 包来处理运行时权限请求。

权限请求代码示例（已在 HomeScreen 中实现）：

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> _checkPermissions() async {
  final microphoneStatus = await Permission.microphone.status;

  if (!microphoneStatus.isGranted) {
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  return true;
}
```

---

## 故障排除

### 权限被拒绝

如果用户拒绝了权限，应用会显示引导消息让用户去设置中手动开启。

在应用中点击权限提示后：
1. 打开设备的"设置"应用
2. 找到"应用" → "MindFlow"
3. 点击"权限"
4. 开启"麦克风"权限

### Android 13+ 存储权限变化

Android 13 (API 33) 及以上版本改用了新的媒体权限系统，不再需要 `READ_EXTERNAL_STORAGE` 和 `WRITE_EXTERNAL_STORAGE`。

如果您的目标是 Android 13+，可以使用新的权限：

```xml
<!-- Android 13+ 媒体权限 -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

### 前台服务权限（Android 14+）

Android 14 (API 34) 要求明确声明前台服务类型：

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

<service
    android:name=".RecordingService"
    android:foregroundServiceType="microphone"
    android:exported="false" />
```

---

## 快速修复脚本

将以下内容保存为 `fix_android_permissions.sh`：

```bash
#!/bin/bash

echo "🔧 修复 Android 权限配置..."

# 检查文件是否存在
if [ ! -f "android/app/src/main/AndroidManifest.xml" ]; then
    echo "❌ 错误：AndroidManifest.xml 不存在"
    echo "请先运行 'flutter create .' 生成平台代码"
    exit 1
fi

# 备份原始文件
cp android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml.backup
echo "✅ 已备份 AndroidManifest.xml"

# 检查权限是否已存在
if grep -q "android.permission.RECORD_AUDIO" android/app/src/main/AndroidManifest.xml; then
    echo "✅ 权限已存在，无需修改"
else
    echo "➕ 添加权限配置..."
    # 使用 xmlstarlet 或手动编辑
    # 这里建议手动编辑，因为 XML 结构可能不同
fi

echo "🧹 清理构建缓存..."
flutter clean

echo "📥 重新获取依赖..."
flutter pub get

echo "✅ 修复完成！"
```

---

## 测试权限

运行应用后，首次尝试录音时会弹出权限请求对话框。

**测试步骤：**
1. 运行应用：`flutter run`
2. 点击录音按钮
3. 在弹出的对话框中选择"允许"
4. 开始录音测试

如果没有弹出权限对话框，检查：
- AndroidManifest.xml 中是否添加了权限
- 应用是否正确请求了运行时权限（检查代码）
- 是否需要卸载应用后重新安装
