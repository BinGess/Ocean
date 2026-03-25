import 'dart:ui';
import 'package:injectable/injectable.dart';
import '../../data/datasources/local/hive_database.dart';

/// 语言设置服务
/// 管理应用的语言偏好设置
@lazySingleton
class LocaleService {
  final HiveDatabase _database;

  static const String _localeKey = 'app_locale';

  // 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh'), // 中文
    Locale('en'), // 英文
  ];

  LocaleService(this._database);

  /// 获取当前保存的语言设置
  /// 返回 null 表示跟随系统
  Locale? getSavedLocale() {
    final localeCode = _database.settingsBox.get(_localeKey) as String?;
    if (localeCode == null || localeCode.isEmpty) {
      return null; // 跟随系统
    }
    return Locale(localeCode);
  }

  /// 保存语言设置
  /// 传入 null 表示跟随系统
  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _database.settingsBox.delete(_localeKey);
    } else {
      await _database.settingsBox.put(_localeKey, locale.languageCode);
    }
  }

  /// 获取实际使用的语言
  /// 如果没有设置，则返回系统语言（如果支持），否则返回中文
  Locale getEffectiveLocale() {
    final savedLocale = getSavedLocale();
    if (savedLocale != null) {
      return savedLocale;
    }

    // 获取系统语言
    final systemLocale = PlatformDispatcher.instance.locale;

    // 检查是否支持系统语言
    for (final supported in supportedLocales) {
      if (supported.languageCode == systemLocale.languageCode) {
        return supported;
      }
    }

    // 默认返回中文
    return const Locale('zh');
  }

  /// 检查是否为跟随系统设置
  bool isFollowingSystem() {
    return getSavedLocale() == null;
  }
}
