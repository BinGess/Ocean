// MindFlow API 调试入口
// 独立的调试应用，仅用于测试豆包 API

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/debug/api_test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境变量
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ 环境变量已加载');
  } catch (e) {
    debugPrint('⚠️ 加载 .env 文件失败: $e');
    debugPrint('⚠️ 应用将使用默认配置运行');
  }

  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindFlow API 调试',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const ApiTestScreen(),
    );
  }
}
