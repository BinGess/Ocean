/// 日总结服务
/// 管理日总结的生成、缓存和更新
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/entities/record.dart';
import '../../data/datasources/local/hive_database.dart';
import '../network/coze_ai_service.dart';

class DailySummaryService {
  final HiveDatabase _database;
  final CozeAIService _cozeAIService;

  /// 防抖计时器，避免频繁生成
  Timer? _debounceTimer;

  /// 最小记录数
  static const int minRecordCount = 2;

  /// 防抖延迟时间（毫秒）
  static const int debounceDelayMs = 5000;

  DailySummaryService({
    required HiveDatabase database,
    required CozeAIService cozeAIService,
  })  : _database = database,
        _cozeAIService = cozeAIService;

  /// 获取某天的日总结（优先使用缓存）
  ///
  /// [date] 日期
  /// 返回 DailySummary，如果不存在则返回 null
  DailySummary? getDailySummary(DateTime date) {
    final key = getDailySummaryKey(date);
    final jsonStr = _database.settingsBox.get(key) as String?;

    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DailySummary.fromJson(json);
    } catch (e) {
      debugPrint('DailySummaryService: 解析日总结失败: $e');
      return null;
    }
  }

  /// 保存日总结到缓存
  Future<void> _saveDailySummary(DailySummary summary) async {
    final key = getDailySummaryKey(summary.date);
    final jsonStr = jsonEncode(summary.toJson());
    await _database.settingsBox.put(key, jsonStr);
    debugPrint('DailySummaryService: 已保存日总结 (${summary.date})');
  }

  /// 检查是否需要重新生成日总结
  ///
  /// [date] 日期
  /// [currentRecordCount] 当前记录数
  /// 返回 true 如果需要重新生成
  bool needsRegeneration(DateTime date, int currentRecordCount) {
    // 记录数不足，不需要生成
    if (currentRecordCount < minRecordCount) {
      return false;
    }

    final existingSummary = getDailySummary(date);

    // 不存在日总结，需要生成
    if (existingSummary == null) {
      return true;
    }

    // 用户已手动覆盖，不自动重新生成
    if (existingSummary.userOverridden) {
      return false;
    }

    // 记录数有变化，需要重新生成
    if (existingSummary.recordCount != currentRecordCount) {
      return true;
    }

    return false;
  }

  /// 生成日总结
  ///
  /// [date] 日期
  /// [records] 当天的记录列表
  /// 返回生成的 DailySummary
  Future<DailySummary?> generateDailySummary(
    DateTime date,
    List<Record> records,
  ) async {
    // 检查记录数量
    if (records.length < minRecordCount) {
      debugPrint('DailySummaryService: 记录数不足 (${records.length} < $minRecordCount)');
      return null;
    }

    // 检查是否需要重新生成
    final existing = getDailySummary(date);
    if (existing != null && existing.userOverridden) {
      debugPrint('DailySummaryService: 用户已手动设置，跳过自动生成');
      return existing;
    }

    debugPrint('DailySummaryService: 开始生成日总结，记录数: ${records.length}');

    try {
      // 构建请求数据
      final summaryRecords = records.map((r) {
        final timeStr = _formatRecordTime(r.createdAt);
        return DailySummaryRecord(
          recordTime: timeStr,
          content: r.transcription,
        );
      }).toList();

      // 调用 AI 生成
      final summary = await _cozeAIService.generateDailySummary(
        summaryRecords,
        date,
      );

      // 保存到缓存
      await _saveDailySummary(summary);

      return summary;
    } catch (e) {
      debugPrint('DailySummaryService: 生成日总结失败: $e');
      return null;
    }
  }

  /// 带防抖的生成日总结
  ///
  /// 在用户连续添加记录时，避免频繁调用 API
  void generateDailySummaryDebounced(
    DateTime date,
    List<Record> records, {
    void Function(DailySummary?)? onComplete,
  }) {
    // 取消之前的计时器
    _debounceTimer?.cancel();

    // 设置新的计时器
    _debounceTimer = Timer(
      const Duration(milliseconds: debounceDelayMs),
      () async {
        final summary = await generateDailySummary(date, records);
        onComplete?.call(summary);
      },
    );
  }

  /// 标记用户已手动设置心情
  ///
  /// 当用户手动选择心情后调用，防止 AI 覆盖用户选择
  Future<void> markUserOverridden(DateTime date) async {
    final existing = getDailySummary(date);
    if (existing != null && !existing.userOverridden) {
      final updated = existing.copyWith(userOverridden: true);
      await _saveDailySummary(updated);
      debugPrint('DailySummaryService: 已标记用户手动设置 ($date)');
    }
  }

  /// 清除用户覆盖标记，允许重新生成
  Future<void> clearUserOverride(DateTime date) async {
    final existing = getDailySummary(date);
    if (existing != null && existing.userOverridden) {
      final updated = existing.copyWith(userOverridden: false);
      await _saveDailySummary(updated);
      debugPrint('DailySummaryService: 已清除用户覆盖标记 ($date)');
    }
  }

  /// 格式化记录时间
  String _formatRecordTime(DateTime time) {
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekDay = weekDays[time.weekday - 1];
    return DateFormat('yyyy-MM-dd').format(time) +
        ' $weekDay ' +
        DateFormat('HH:mm').format(time);
  }

  /// 清理资源
  void dispose() {
    _debounceTimer?.cancel();
  }
}
