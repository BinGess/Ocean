/// 基础 UseCase 抽象类
/// 所有业务用例都继承此类

abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// 无参数 UseCase
abstract class UseCaseNoParams<Type> {
  Future<Type> call();
}

/// 同步 UseCase
abstract class SyncUseCase<Type, Params> {
  Type call(Params params);
}

/// 无参数同步 UseCase
abstract class SyncUseCaseNoParams<Type> {
  Type call();
}

/// Stream UseCase（用于实时数据）
abstract class StreamUseCase<Type, Params> {
  Stream<Type> call(Params params);
}
