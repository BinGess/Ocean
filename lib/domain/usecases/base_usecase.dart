// 基础 UseCase 抽象类
// 所有业务用例都继承此类

abstract class UseCase<Result, Params> {
  Future<Result> call(Params params);
}

// 无参数 UseCase
abstract class UseCaseNoParams<Result> {
  Future<Result> call();
}

// 同步 UseCase
abstract class SyncUseCase<Result, Params> {
  Result call(Params params);
}

// 无参数同步 UseCase
abstract class SyncUseCaseNoParams<Result> {
  Result call();
}

// Stream UseCase（用于实时数据）
abstract class StreamUseCase<Result, Params> {
  Stream<Result> call(Params params);
}
