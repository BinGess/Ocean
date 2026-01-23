/// MindFlow 应用入口
/// 情绪觉察日记 App

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
import 'presentation/screens/journal/journal_screen.dart';
import 'presentation/screens/insights/insights_screen.dart';

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
        home: const MainNavigation(),
      ),
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
  int _currentIndex = 0;

  // 四个主要页面
  final List<Widget> _screens = const [
    HomeScreen(), // 首页（录音）
    RecordsScreen(), // 碎片记录
    JournalScreen(), // 日记
    InsightsScreen(), // 周洞察
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notes),
            label: '碎片',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: '日记',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: '洞察',
          ),
        ],
      ),
    );
  }
}
