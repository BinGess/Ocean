@echo off
REM MindFlow Flutter 项目快速设置脚本 (Windows)
REM 使用方法: 双击运行或在 CMD 中执行 setup.bat

echo ================================
echo MindFlow Flutter 项目设置
echo ================================
echo.

REM 检查 Flutter 是否安装
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] Flutter 未安装或不在 PATH 中
    echo 请参考 SETUP.md 安装 Flutter SDK
    pause
    exit /b 1
)

echo [OK] Flutter 已安装
flutter --version
echo.

REM 运行 flutter doctor
echo 检查 Flutter 环境...
flutter doctor
echo.

REM 询问用户是否继续
set /p continue="是否继续设置项目？(y/n): "
if /i not "%continue%"=="y" exit /b 0

REM 第一步：生成平台代码
echo.
echo [1/5] 生成平台代码...
if exist "android" if exist "ios" (
    echo [警告] 平台代码已存在，跳过...
) else (
    flutter create . --org com.mindflow.app --project-name mindflow
    echo [OK] 平台代码生成完成
)

REM 第二步：安装依赖
echo.
echo [2/5] 安装 Flutter 依赖...
flutter pub get
echo [OK] 依赖安装完成

REM 第三步：生成代码
echo.
echo [3/5] 运行代码生成...
flutter pub run build_runner build --delete-conflicting-outputs
echo [OK] 代码生成完成

REM 第四步：配置环境变量
echo.
echo [4/5] 配置环境变量...
if not exist ".env" (
    copy .env.example .env
    echo [OK] 已创建 .env 文件
    echo [警告] 请编辑 .env 文件，填入您的豆包 API 密钥
) else (
    echo [警告] .env 文件已存在，跳过...
)

REM 第五步：检查设备
echo.
echo [5/5] 检查可用设备...
flutter devices

echo.
echo ================================
echo 设置完成！
echo ================================
echo.
echo 下一步:
echo 1. 编辑 .env 文件，填入豆包 API 密钥
echo 2. 运行 'flutter run' 启动应用
echo 3. 参考 SETUP.md 了解更多配置选项
echo.
echo 常用命令:
echo   flutter run              # 运行应用（Debug 模式）
echo   flutter run --release    # 运行应用（Release 模式）
echo   flutter devices          # 查看可用设备
echo   flutter clean            # 清理构建缓存
echo   flutter analyze          # 代码分析
echo.

pause
