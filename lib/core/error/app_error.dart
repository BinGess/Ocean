// 统一异常封装
// 用于跨层传递可读的错误信息与错误类型

class AppError implements Exception {
  final AppErrorCode code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'AppError(${code.name}): $message';
  }

  AppError copyWith({
    AppErrorCode? code,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: code ?? this.code,
      message: message ?? this.message,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  static AppError from(Object error, {AppErrorCode fallback = AppErrorCode.unknown}) {
    if (error is AppError) return error;
    return AppError(
      code: fallback,
      message: error.toString(),
      cause: error,
    );
  }
}

enum AppErrorCode {
  asrUnavailable,
  llmUnavailable,
  network,
  timeout,
  unauthorized,
  permissionDenied,
  invalidData,
  notFound,
  serviceUnavailable,
  parsing,
  io,
  unknown,
}

