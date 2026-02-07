// MindFlow 应用入口
// 情绪觉察日记 App

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection.dart';
import 'presentation/bloc/audio/audio_bloc.dart';
import 'presentation/bloc/audio/audio_event.dart';
import 'presentation/bloc/record/record_bloc.dart';
import 'presentation/bloc/insight/insight_bloc.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/records/records_screen.dart';
import 'presentation/screens/insights/insights_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

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

  // 初始化依赖注入
  await configureDependencies();

  runApp(const MindFlowApp());
}

class MindFlowApp extends StatelessWidget {
  const MindFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 全局 BLoC 提供者
        BlocProvider(
          create: (context) => getIt<AudioBloc>()
            ..add(const AudioCheckPermission()),
        ),
        BlocProvider(
          create: (context) => getIt<RecordBloc>(),
        ),
        BlocProvider(
          create: (context) => getIt<InsightBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'MindFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // 后续可以从设置中读取
        home: const AppEntryPoint(),
      ),
    );
  }
}

/// 应用入口点 - 管理开屏页到主导航的切换
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // 开屏期间预先请求权限和预热资源
    _requestPermissionsAndWarmUp();
  }

  /// 请求权限并预热资源
  void _requestPermissionsAndWarmUp() {
    // 延迟 200ms 等待 BLoC 初始化完成
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final audioBloc = context.read<AudioBloc>();

      // 请求麦克风权限
      if (!audioBloc.state.hasPermission) {
        audioBloc.add(const AudioRequestPermission());
      }

      // 预热录音资源
      audioBloc.add(const AudioWarmUp());
    });
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const MainNavigation();
  }
}

/// 主导航结构
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 1; // 默认首页

  // 三个主要页面
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      RecordsScreen(
        onNavigateToHome: () {
          setState(() {
            _currentIndex = 1; // 跳转到首页
          });
        },
      ), // 记录
      const HomeScreen(), // 首页（录音）
      const InsightsScreen(), // 洞察
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 72,  // 增加高度以提供更大的点击区域
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: Icons.folder_outlined,
                    activeIcon: Icons.folder,
                    label: '记录',
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 1,
                    icon: Icons.circle_outlined,
                    activeIcon: Icons.circle,
                    label: '瞬记',
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 2,
                    icon: Icons.auto_awesome_outlined,
                    activeIcon: Icons.auto_awesome,
                    label: '洞察',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFFC4A57B) : const Color(0xFFB8B8B8);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 使用整个可用区域作为点击目标
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 26,  // 稍微增大图标
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,  // 稍微增大字体
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
