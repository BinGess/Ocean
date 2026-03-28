// MindFlow 应用入口
// 情绪觉察日记 App

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection.dart';
import 'core/services/app_lock_service.dart';
import 'core/services/icloud_sync_service.dart';
import 'l10n/app_localizations.dart';
import 'presentation/bloc/audio/audio_bloc.dart';
import 'presentation/bloc/audio/audio_event.dart';
import 'presentation/bloc/record/record_bloc.dart';
import 'presentation/bloc/insight/insight_bloc.dart';
import 'presentation/bloc/locale/locale_bloc.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/records/records_screen.dart';
import 'presentation/screens/insights/insights_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/nvc_onboarding_screen.dart';
import 'presentation/screens/app_lock/lock_screen.dart';
import 'presentation/widgets/app_lock/privacy_blur_overlay.dart';
import 'data/datasources/local/hive_database.dart';

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
  await getIt<ICloudSyncService>().initializeOnLaunch();

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
          create: (context) => getIt<AudioBloc>(),
        ),
        BlocProvider(
          create: (context) => getIt<RecordBloc>(),
        ),
        BlocProvider(
          create: (context) => getIt<InsightBloc>(),
        ),
        BlocProvider(
          create: (context) => getIt<LocaleBloc>()..add(const LocaleLoad()),
        ),
      ],
      child: BlocBuilder<LocaleBloc, LocaleState>(
        builder: (context, localeState) {
          return MaterialApp(
            title: 'MindFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            // 本地化配置
            locale: localeState.effectiveLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AppEntryPoint(),
          );
        },
      ),
    );
  }
}

/// 应用入口点 - 管理开屏页到主导航的切换，以及应用锁
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _showOnboarding = false;
  bool _showLockScreen = false;
  bool _showPrivacyBlur = false;
  bool _isCheckingLock = false;

  final _appLockService = getIt<AppLockService>();
  final _iCloudSyncService = getIt<ICloudSyncService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 注：不再在 initState 中请求权限，而是在 splash 结束后按顺序请求
    // 延迟检查锁屏，确保 widget 树已完成构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkLockOnStart();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App 进入后台或失去焦点
        _onAppBackground();
        break;
      case AppLifecycleState.resumed:
        // App 恢复到前台
        _onAppForeground();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkLockOnStart() async {
    if (_isCheckingLock) return;
    _isCheckingLock = true;

    try {
      final shouldLock = await _appLockService.shouldShowLockScreen();
      if (shouldLock && mounted) {
        setState(() {
          _showLockScreen = true;
        });
      }
    } catch (e) {
      debugPrint('AppEntryPoint: 检查锁屏失败: $e');
    } finally {
      _isCheckingLock = false;
    }
  }

  void _onAppBackground() async {
    try {
      unawaited(_iCloudSyncService.syncNow());
      _appLockService.onAppBackground();
      // 显示隐私遮罩
      final isEnabled = await _appLockService.isEnabled;
      if (isEnabled && mounted) {
        setState(() {
          _showPrivacyBlur = true;
        });
      }
    } catch (e) {
      debugPrint('AppEntryPoint: 处理后台切换失败: $e');
    }
  }

  void _onAppForeground() async {
    // 隐藏隐私遮罩
    if (mounted) {
      setState(() {
        _showPrivacyBlur = false;
      });
    }

    try {
      unawaited(_iCloudSyncService.refreshFromCloudIfNeeded());
      // 检查是否需要显示锁屏
      final shouldLock = await _appLockService.shouldShowLockScreen();
      if (shouldLock && mounted) {
        setState(() {
          _showLockScreen = true;
        });
      }
    } catch (e) {
      debugPrint('AppEntryPoint: 检查前台锁屏失败: $e');
    }
  }

  void _onUnlocked() {
    setState(() {
      _showLockScreen = false;
    });
  }

  /// 请求权限并预热资源
  void _requestPermissionsAndWarmUp() {
    // 延迟 200ms 等待 BLoC 初始化完成后请求麦克风权限
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final audioBloc = context.read<AudioBloc>();

      // 请求麦克风权限
      if (!audioBloc.state.hasPermission) {
        audioBloc.add(const AudioRequestPermission());
      }

      // 预热录音资源
      audioBloc.add(const AudioWarmUp());

      // 麦克风权限请求后再触发网络权限弹窗（延迟足够时间让用户处理音频权限）
      Future.delayed(const Duration(milliseconds: 1000), () {
        _triggerNetworkPermission();
      });
    });
  }

  /// 触发网络权限
  /// iOS 首次发起网络请求时会弹出"是否允许使用无线数据"对话框
  void _triggerNetworkPermission() {
    // 向 ASR 服务器域名发起请求，确保与后续 WebSocket 连接使用同一域名
    // 这样 iOS 只会弹出一次网络权限对话框
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    // 使用 ASR 服务的域名（与 WebSocket 连接同域名）
    dio.get('https://openspeech.bytedance.com').then((_) {
      dio.close();
    }).catchError((_) {
      dio.close();
    });
  }

  void _onSplashComplete() async {
    // 检查是否需要展示新用户引导
    bool needsOnboarding = false;
    try {
      final db = getIt<HiveDatabase>();
      final completed = db.settingsBox.get('onboarding_completed',
          defaultValue: false);
      final alwaysShow = db.settingsBox.get('show_onboarding_always',
          defaultValue: false);
      needsOnboarding = completed != true || alwaysShow == true;
    } catch (e) {
      debugPrint('AppEntryPoint: 检查 onboarding flag 失败: $e');
    }

    setState(() {
      _showSplash = false;
      _showOnboarding = needsOnboarding;
    });

    // Splash 结束后，直接请求麦克风权限和预热（无论是否显示引导）
    if (mounted) {
      _requestPermissionsAndWarmUp();
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 开屏页
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // 新用户 NVC 引导页
    if (_showOnboarding) {
      return NVCOnboardingScreen(onComplete: _onOnboardingComplete);
    }

    // 主内容 + 锁屏层 + 隐私遮罩层
    return Stack(
      children: [
        // 主导航
        const MainNavigation(),

        // 锁屏界面
        if (_showLockScreen) LockScreen(onUnlocked: _onUnlocked),

        // 隐私遮罩（后台防窥）
        if (_showPrivacyBlur && !_showLockScreen) const PrivacyBlurOverlay(),
      ],
    );
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
          color: AppColors.bgCard,
          border: const Border(
            top: BorderSide(
              color: AppColors.borderLight,
              width: 0.7,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textSecondary.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 72, // 增加高度以提供更大的点击区域
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        icon: Icons.folder_outlined,
                        activeIcon: Icons.folder,
                        label: l10n.navRecords,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        icon: Icons.circle_outlined,
                        activeIcon: Icons.circle,
                        label: l10n.navHome,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.auto_awesome_outlined,
                        activeIcon: Icons.auto_awesome,
                        label: l10n.navInsights,
                      ),
                    ),
                  ],
                );
              },
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
    final color = isActive ? AppColors.accent : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 26,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
