// AppError -> 用户友好提示映射

import 'dart:async';
import 'app_error.dart';

class AppErrorMapper {
  AppErrorMapper._();

  static String message(Object error) {
    if (error is AppError) {
      switch (error.code) {
        case AppErrorCode.asrUnavailable:
          return '语音识别服务暂不可用，请稍后再试';
        case AppErrorCode.llmUnavailable:
          return '分析服务暂不可用，请稍后再试';
        case AppErrorCode.timeout:
          return '请求超时，请检查网络后重试';
        case AppErrorCode.network:
          return '网络异常，请检查网络连接';
        case AppErrorCode.unauthorized:
          return '认证失败，请检查配置';
        case AppErrorCode.permissionDenied:
          return '权限不足，请在设置中授权';
        case AppErrorCode.invalidData:
          return '数据无效，请稍后重试';
        case AppErrorCode.notFound:
          return '资源不存在或已删除';
        case AppErrorCode.serviceUnavailable:
          return '服务暂不可用，请稍后再试';
        case AppErrorCode.parsing:
          return '解析失败，请稍后重试';
        case AppErrorCode.io:
          return '本地文件处理失败，请重试';
        case AppErrorCode.unknown:
        default:
          return error.message.isNotEmpty ? error.message : '操作失败，请稍后重试';
      }
    }

    if (error is TimeoutException) {
      return '请求超时，请检查网络后重试';
    }

    final lower = error.toString().toLowerCase();
    if (lower.contains('permission')) {
      return '权限不足，请在设置中授权';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return '网络异常，请检查网络连接';
    }

    return '操作失败，请稍后重试';
  }

  static AppErrorCode? codeOf(Object error) {
    if (error is AppError) {
      return error.code;
    }
    if (error is TimeoutException) {
      return AppErrorCode.timeout;
    }

    final lower = error.toString().toLowerCase();
    if (lower.contains('permission')) {
      return AppErrorCode.permissionDenied;
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return AppErrorCode.network;
    }
    return null;
  }
}

