/// 依赖注入配置
/// 使用 get_it 进行依赖管理

import 'package:get_it/get_it.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/repositories/insight_repository.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../data/repositories/record_repository_impl.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../data/repositories/insight_repository_impl.dart';
import '../../data/datasources/local/hive_database.dart';
import '../../data/datasources/remote/doubao_datasource.dart';
import '../network/doubao_asr_client.dart';
import '../network/doubao_llm_client.dart';
import '../constants/app_constants.dart';
import '../../presentation/bloc/audio/audio_bloc.dart';

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
      apiKey: EnvConfig.doubaoLLMApiKey,
      endpoint: AppConstants.doubaoLlmEndpoint,
    ),
  );

  // ===== Data Sources =====

  // Hive 数据库
  final hiveDatabase = HiveDatabase();
  await hiveDatabase.init();
  getIt.registerSingleton<HiveDatabase>(hiveDatabase);

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
    ),
  );

  // 洞察仓储
  getIt.registerLazySingleton<InsightRepository>(
    () => InsightRepositoryImpl(
      database: getIt<HiveDatabase>(),
    ),
  );

  // ===== BLoCs =====

  // 音频 BLoC（工厂模式，每次创建新实例）
  getIt.registerFactory<AudioBloc>(
    () => AudioBloc(
      audioRepository: getIt<AudioRepository>(),
    ),
  );

  // 后续可以添加更多 BLoC
  // getIt.registerFactory<RecordBloc>(() => RecordBloc(...));
  // getIt.registerFactory<InsightBloc>(() => InsightBloc(...));
}

/// 清理资源
Future<void> cleanupDependencies() async {
  // 清理 BLoC
  // 注意：BLoC 由 Flutter 的 BlocProvider 管理生命周期

  // 清理网络客户端
  getIt<DoubaoLLMClient>().dispose();
  getIt<DoubaoASRClient>().dispose();

  // 清理数据库
  await getIt<HiveDatabase>().close();

  // 重置 GetIt
  await getIt.reset();
}
