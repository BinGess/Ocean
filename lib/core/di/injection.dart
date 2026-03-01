/// 依赖注入配置
/// 使用 get_it 进行依赖管理
library;

import 'package:get_it/get_it.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/repositories/insight_repository.dart';
import '../../domain/usecases/create_quick_note_usecase.dart';
import '../../domain/usecases/get_records_usecase.dart';
import '../../domain/usecases/update_record_usecase.dart';
import '../../domain/usecases/generate_weekly_insight_usecase.dart';
import '../../domain/usecases/generate_insight_report_usecase.dart';
import '../../domain/usecases/get_weekly_insights_usecase.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../data/repositories/record_repository_impl.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../data/repositories/insight_repository_impl.dart';
import '../../data/repositories/quotes_repository.dart';
import '../../data/datasources/local/hive_database.dart';
import '../../data/datasources/remote/doubao_datasource.dart';
import '../network/doubao_asr_client.dart';
import '../network/doubao_llm_client.dart';
import '../network/coze_ai_service.dart';
import '../constants/app_constants.dart';
import '../services/app_lock_service.dart';
import '../services/ai_auth_service.dart';
import '../services/home_background_theme_service.dart';
import '../services/quote_preloader.dart';
import '../services/quote_update_manager.dart';
import '../../presentation/bloc/audio/audio_bloc.dart';
import '../../presentation/bloc/record/record_bloc.dart';
import '../../presentation/bloc/insight/insight_bloc.dart';

final getIt = GetIt.instance;

/// 配置所有依赖
Future<void> configureDependencies() async {
  // ===== Core / Network =====

  // 豆包 ASR 客户端
  getIt.registerLazySingleton<DoubaoASRClient>(
    () => DoubaoASRClient(),
  );

  // 豆包 LLM 客户端
  getIt.registerLazySingleton<DoubaoLLMClient>(
    () => DoubaoLLMClient(
      apiKey: EnvConfig.doubaoLlmApiKey,
      endpoint: AppConstants.doubaoLlmEndpoint,
    ),
  );

  // Coze AI 服务（智能体）
  getIt.registerLazySingleton<CozeAIService>(
    () => CozeAIService(),
  );

  // ===== Services =====

  // 应用锁服务
  final appLockService = AppLockService();
  await appLockService.init();
  getIt.registerSingleton<AppLockService>(appLockService);

  // AI授权服务
  final aiAuthService = AIAuthService();
  await aiAuthService.init();
  getIt.registerSingleton<AIAuthService>(aiAuthService);

  // ===== Data Sources =====

  // Hive 数据库
  final hiveDatabase = HiveDatabase();
  await hiveDatabase.init();
  getIt.registerSingleton<HiveDatabase>(hiveDatabase);

  // 首页背景主题服务（A/B 方案切换）
  final homeBackgroundThemeService = HomeBackgroundThemeService(
    hiveDatabase: hiveDatabase,
  );
  await homeBackgroundThemeService.init();
  getIt.registerSingleton<HomeBackgroundThemeService>(
    homeBackgroundThemeService,
  );

  // 豆包远程数据源
  getIt.registerLazySingleton<DoubaoDataSource>(
    () => DoubaoDataSource(
      asrClient: getIt<DoubaoASRClient>(),
      llmClient: getIt<DoubaoLLMClient>(),
    ),
  );

  // ===== Repositories =====

  // 音频仓储
  getIt.registerLazySingleton<AudioRepository>(
    () => AudioRepositoryImpl(),
  );

  // 记录仓储
  getIt.registerLazySingleton<RecordRepository>(
    () => RecordRepositoryImpl(
      database: getIt<HiveDatabase>(),
    ),
  );

  // AI 仓储
  getIt.registerLazySingleton<AIRepository>(
    () => AIRepositoryImpl(
      doubaoDataSource: getIt<DoubaoDataSource>(),
      cozeAIService: getIt<CozeAIService>(),
    ),
  );

  // 洞察仓储
  getIt.registerLazySingleton<InsightRepository>(
    () => InsightRepositoryImpl(
      database: getIt<HiveDatabase>(),
    ),
  );

  // 文案仓储
  getIt.registerLazySingleton<QuotesRepository>(
    () => QuotesRepository(
      hiveDatabase: getIt<HiveDatabase>(),
    ),
  );

  // 文案预加载器（离线模式支持）
  getIt.registerLazySingleton<QuotePreloader>(
    () => QuotePreloader(
      quotesRepository: getIt<QuotesRepository>(),
    ),
  );

  // 文案更新管理器（版本控制和定期更新）
  getIt.registerLazySingleton<QuoteUpdateManager>(
    () => QuoteUpdateManager(
      quotesRepository: getIt<QuotesRepository>(),
      hiveDatabase: getIt<HiveDatabase>(),
    ),
  );

  // ===== Use Cases =====

  // 创建快速笔记
  getIt.registerLazySingleton<CreateQuickNoteUseCase>(
    () => CreateQuickNoteUseCase(
      recordRepository: getIt<RecordRepository>(),
      aiRepository: getIt<AIRepository>(),
    ),
  );

  // 获取记录列表
  getIt.registerLazySingleton<GetRecordsUseCase>(
    () => GetRecordsUseCase(
      recordRepository: getIt<RecordRepository>(),
    ),
  );

  // 更新记录
  getIt.registerLazySingleton<UpdateRecordUseCase>(
    () => UpdateRecordUseCase(
      recordRepository: getIt<RecordRepository>(),
    ),
  );

  // 生成周洞察（旧版）
  getIt.registerLazySingleton<GenerateWeeklyInsightUseCase>(
    () => GenerateWeeklyInsightUseCase(
      recordRepository: getIt<RecordRepository>(),
      aiRepository: getIt<AIRepository>(),
      insightRepository: getIt<InsightRepository>(),
    ),
  );

  // 生成洞察报告（新版 - 使用 Coze 智能体）
  getIt.registerLazySingleton<GenerateInsightReportUseCase>(
    () => GenerateInsightReportUseCase(
      recordRepository: getIt<RecordRepository>(),
      aiRepository: getIt<AIRepository>(),
    ),
  );

  // 获取周洞察列表
  getIt.registerLazySingleton<GetWeeklyInsightsUseCase>(
    () => GetWeeklyInsightsUseCase(
      insightRepository: getIt<InsightRepository>(),
    ),
  );

  // ===== BLoCs =====

  // 音频 BLoC（工厂模式，每次创建新实例）
  getIt.registerFactory<AudioBloc>(
    () => AudioBloc(
      audioRepository: getIt<AudioRepository>(),
      asrClient: getIt<DoubaoASRClient>(),
    ),
  );

  // 记录 BLoC
  getIt.registerFactory<RecordBloc>(
    () => RecordBloc(
      createQuickNoteUseCase: getIt<CreateQuickNoteUseCase>(),
      getRecordsUseCase: getIt<GetRecordsUseCase>(),
      updateRecordUseCase: getIt<UpdateRecordUseCase>(),
      recordRepository: getIt<RecordRepository>(),
      aiRepository: getIt<AIRepository>(),
      aiAuthService: getIt<AIAuthService>(),
    ),
  );

  // 洞察 BLoC
  getIt.registerFactory<InsightBloc>(
    () => InsightBloc(
      generateWeeklyInsightUseCase: getIt<GenerateWeeklyInsightUseCase>(),
      generateInsightReportUseCase: getIt<GenerateInsightReportUseCase>(),
      getWeeklyInsightsUseCase: getIt<GetWeeklyInsightsUseCase>(),
      insightRepository: getIt<InsightRepository>(),
      aiAuthService: getIt<AIAuthService>(),
    ),
  );
}

/// 清理资源
Future<void> cleanupDependencies() async {
  // 清理 BLoC
  // 注意：BLoC 由 Flutter 的 BlocProvider 管理生命周期

  // 清理服务
  getIt<AppLockService>().dispose();
  getIt<AIAuthService>().dispose();
  getIt<HomeBackgroundThemeService>().dispose();

  // 清理网络客户端
  getIt<DoubaoLLMClient>().dispose();
  getIt<DoubaoASRClient>().dispose();

  // 清理数据库
  await getIt<HiveDatabase>().close();

  // 重置 GetIt
  await getIt.reset();
}
