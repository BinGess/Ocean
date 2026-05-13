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
import '../../domain/usecases/build_weekly_analysis_usecase.dart';
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
import '../network/ocean_api_client.dart';
import '../constants/app_constants.dart';
import '../services/app_lock_service.dart';
import '../services/ai_auth_service.dart';
import '../services/quote_preloader.dart';
import '../services/quote_update_manager.dart';
import '../services/daily_summary_service.dart';
import '../services/icloud_sync_service.dart';
import '../services/ocean_sync_service.dart';
import '../services/ocean_account_cache_service.dart';
import '../services/ocean_account_service.dart';
import '../services/ocean_installation_service.dart';
import '../services/pro_subscription_service.dart';
import '../../presentation/bloc/audio/audio_bloc.dart';
import '../../presentation/bloc/record/record_bloc.dart';
import '../../presentation/bloc/insight/insight_bloc.dart';
import '../../presentation/bloc/locale/locale_bloc.dart';
import '../services/locale_service.dart';

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

  getIt.registerLazySingleton<OceanTokenStore>(
    () => OceanSecureTokenStore(),
  );

  getIt.registerLazySingleton<OceanApiClient>(
    () => OceanApiClient(
      tokenStore: getIt<OceanTokenStore>(),
    ),
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

  // 语言服务（需要在 HiveDatabase 之后初始化，这里先注册工厂）
  // 实际初始化在 HiveDatabase 之后

  // ===== Data Sources =====

  // Hive 数据库
  final hiveDatabase = HiveDatabase();
  await hiveDatabase.init();
  getIt.registerSingleton<HiveDatabase>(hiveDatabase);

  final oceanInstallationService = OceanInstallationService(
    database: hiveDatabase,
    tokenStore: getIt<OceanTokenStore>(),
  );
  await oceanInstallationService.reconcileInstallState();
  getIt.registerSingleton<OceanInstallationService>(oceanInstallationService);

  final iCloudSyncService = ICloudSyncService(
    database: hiveDatabase,
  );
  await iCloudSyncService.init();
  getIt.registerSingleton<ICloudSyncService>(iCloudSyncService);

  // Pro 订阅服务
  final proSubscriptionService = ProSubscriptionService(database: hiveDatabase);
  await proSubscriptionService.init();
  getIt.registerSingleton<ProSubscriptionService>(proSubscriptionService);

  // 语言服务
  getIt.registerLazySingleton<LocaleService>(
    () => LocaleService(getIt<HiveDatabase>()),
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
      recordsApi: getIt<OceanApiClient>(),
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
      userDataApi: getIt<OceanApiClient>(),
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

  // 日总结服务
  getIt.registerLazySingleton<DailySummaryService>(
    () => DailySummaryService(
      database: getIt<HiveDatabase>(),
      cozeAIService: getIt<CozeAIService>(),
      userDataApi: getIt<OceanApiClient>(),
    ),
  );

  getIt.registerLazySingleton<OceanSyncService>(
    () => OceanSyncService(
      api: getIt<OceanApiClient>(),
      dataStore: HiveOceanSyncDataStore(getIt<HiveDatabase>()),
      stateStore: HiveOceanSyncStateStore(getIt<HiveDatabase>()),
    ),
  );

  getIt.registerLazySingleton<OceanAccountCacheService>(
    () => OceanAccountCacheService(getIt<HiveDatabase>()),
  );

  getIt.registerLazySingleton<OceanAccountDataRefreshService>(
    () => OceanAccountDataRefreshService(),
  );

  getIt.registerLazySingleton<OceanAccountService>(
    () => OceanAccountService(
      api: getIt<OceanApiClient>(),
      syncService: getIt<OceanSyncService>(),
      cacheService: getIt<OceanAccountCacheService>(),
      refreshService: getIt<OceanAccountDataRefreshService>(),
      iCloudSyncService: getIt<ICloudSyncService>(),
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

  getIt.registerLazySingleton<BuildWeeklyAnalysisUseCase>(
    () => BuildWeeklyAnalysisUseCase(
      recordRepository: getIt<RecordRepository>(),
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
      dailySummaryService: getIt<DailySummaryService>(),
    ),
  );

  // 洞察 BLoC
  getIt.registerFactory<InsightBloc>(
    () => InsightBloc(
      generateWeeklyInsightUseCase: getIt<GenerateWeeklyInsightUseCase>(),
      generateInsightReportUseCase: getIt<GenerateInsightReportUseCase>(),
      getWeeklyInsightsUseCase: getIt<GetWeeklyInsightsUseCase>(),
      buildWeeklyAnalysisUseCase: getIt<BuildWeeklyAnalysisUseCase>(),
      insightRepository: getIt<InsightRepository>(),
      aiAuthService: getIt<AIAuthService>(),
    ),
  );

  // 语言 BLoC
  getIt.registerFactory<LocaleBloc>(
    () => LocaleBloc(getIt<LocaleService>()),
  );
}

/// 清理资源
Future<void> cleanupDependencies() async {
  // 清理 BLoC
  // 注意：BLoC 由 Flutter 的 BlocProvider 管理生命周期

  // 清理服务
  getIt<AppLockService>().dispose();
  getIt<AIAuthService>().dispose();
  getIt<DailySummaryService>().dispose();
  getIt<ICloudSyncService>().dispose();
  getIt<ProSubscriptionService>().dispose();

  // 清理网络客户端
  getIt<DoubaoLLMClient>().dispose();
  getIt<DoubaoASRClient>().dispose();

  // 清理数据库
  await getIt<HiveDatabase>().close();

  // 重置 GetIt
  await getIt.reset();
}
