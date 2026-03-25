import 'dart:convert';

import '../../domain/entities/record.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/entities/insight_report_cache.dart';

/// 导出格式类型
enum ExportFormat { json, csv, markdown }

/// 导出数据格式化器
class ExportFormatter {
  const ExportFormatter._();

  // ─── JSON ───────────────────────────────────────────

  static String recordsToJson(List<Record> records) {
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'count': records.length,
      'records': records.map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String insightsToJson(List<InsightReportCache> caches) {
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'count': caches.length,
      'reports': caches
          .map((c) => {
                'cached_at': c.cachedAt.toIso8601String(),
                'report': c.report.toJson(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ─── CSV ────────────────────────────────────────────

  /// UTF-8 BOM，确保 Excel / WPS 正确识别中文
  static const _bom = '\uFEFF';

  static String recordsToCsv(List<Record> records) {
    final buf = StringBuffer();
    buf.write(_bom);
    buf.writeln(
      '日期,时间,类型,标题,内容,时长(秒),情绪标签,需求标签,'
      'NVC·观察,NVC·感受,NVC·需求,NVC·请求,NVC·洞察',
    );
    for (final r in records) {
      buf.writeln([
        _csvDate(r.createdAt),
        _csvTime(r.createdAt),
        _recordTypeName(r.type),
        _esc(r.title ?? ''),
        _esc(r.transcription),
        r.duration?.toStringAsFixed(0) ?? '',
        _esc(r.moods?.join('、') ?? ''),
        _esc(r.needs?.join('、') ?? ''),
        _esc(r.nvc?.observation ?? ''),
        _esc(_feelingsText(r.nvc?.feelings)),
        _esc(_needsText(r.nvc?.needs)),
        _esc(r.nvc?.request ?? ''),
        _esc(r.nvc?.insight ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static String insightsToCsv(List<InsightReportCache> caches) {
    final buf = StringBuffer();
    buf.write(_bom);
    buf.writeln(
      '周范围,报告日期,情绪概览,高频情境,模式假设,行动建议,记录数',
    );
    for (final c in caches) {
      final r = c.report;
      buf.writeln([
        _esc(r.weekRange),
        _csvDate(c.cachedAt),
        _esc(r.emotionOverview.summary),
        _esc(r.highFrequencyEmotions
            .map((e) => '[${e.time}] ${e.content}')
            .join('\n')),
        _esc(r.patternHypothesis.text),
        _esc(r.actionSuggestions
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value.title}：${e.value.content}')
            .join('\n')),
        r.recordCount?.toString() ?? '',
      ].join(','));
    }
    return buf.toString();
  }

  // ─── Markdown ───────────────────────────────────────

  static String recordsToMarkdown(List<Record> records) {
    final buf = StringBuffer();
    buf.writeln('# 瞬记 · 记录导出');
    buf.writeln();
    buf.writeln('> 导出时间：${_friendlyDate(DateTime.now())}　共 ${records.length} 条记录');
    buf.writeln();

    _writeRecordStats(buf, records);
    buf.writeln('---');
    buf.writeln();

    final grouped = _groupRecordsByDate(records);
    for (final entry in grouped.entries) {
      buf.writeln('## ${entry.key}（${entry.value.length} 条）');
      buf.writeln();
      for (final r in entry.value) {
        _writeRecordMarkdown(buf, r);
      }
    }
    return buf.toString();
  }

  static String insightsToMarkdown(List<InsightReportCache> caches) {
    final buf = StringBuffer();
    buf.writeln('# 瞬记 · 洞察报告导出');
    buf.writeln();
    buf.writeln('> 导出时间：${_friendlyDate(DateTime.now())}　共 ${caches.length} 份报告');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    for (final c in caches) {
      _writeInsightMarkdown(buf, c.report);
    }
    return buf.toString();
  }

  // ─── Combined export ────────────────────────────────

  static String combinedExport({
    required List<Record> records,
    required List<InsightReportCache> insights,
    required ExportFormat format,
  }) {
    switch (format) {
      case ExportFormat.json:
        final payload = {
          'exported_at': DateTime.now().toIso8601String(),
          'records_count': records.length,
          'insights_count': insights.length,
          'records': records.map((r) => r.toJson()).toList(),
          'insights': insights
              .map((c) => {
                    'cached_at': c.cachedAt.toIso8601String(),
                    'report': c.report.toJson(),
                  })
              .toList(),
        };
        return const JsonEncoder.withIndent('  ').convert(payload);
      case ExportFormat.csv:
        return _combinedCsv(records, insights);
      case ExportFormat.markdown:
        return _combinedMarkdown(records, insights);
    }
  }

  static String _combinedCsv(
      List<Record> records, List<InsightReportCache> insights) {
    final buf = StringBuffer();
    buf.write(_bom);

    if (records.isNotEmpty) {
      // 记录表
      buf.writeln(
        '日期,时间,类型,标题,内容,时长(秒),情绪标签,需求标签,'
        'NVC·观察,NVC·感受,NVC·需求,NVC·请求,NVC·洞察',
      );
      for (final r in records) {
        buf.writeln([
          _csvDate(r.createdAt),
          _csvTime(r.createdAt),
          _recordTypeName(r.type),
          _esc(r.title ?? ''),
          _esc(r.transcription),
          r.duration?.toStringAsFixed(0) ?? '',
          _esc(r.moods?.join('、') ?? ''),
          _esc(r.needs?.join('、') ?? ''),
          _esc(r.nvc?.observation ?? ''),
          _esc(_feelingsText(r.nvc?.feelings)),
          _esc(_needsText(r.nvc?.needs)),
          _esc(r.nvc?.request ?? ''),
          _esc(r.nvc?.insight ?? ''),
        ].join(','));
      }
    }

    if (records.isNotEmpty && insights.isNotEmpty) {
      // 空行分隔两个表
      buf.writeln();
      buf.writeln();
    }

    if (insights.isNotEmpty) {
      // 洞察表
      buf.writeln(
        '周范围,报告日期,情绪概览,高频情境,模式假设,行动建议,记录数',
      );
      for (final c in insights) {
        final r = c.report;
        buf.writeln([
          _esc(r.weekRange),
          _csvDate(c.cachedAt),
          _esc(r.emotionOverview.summary),
          _esc(r.highFrequencyEmotions
              .map((e) => '[${e.time}] ${e.content}')
              .join('\n')),
          _esc(r.patternHypothesis.text),
          _esc(r.actionSuggestions
              .asMap()
              .entries
              .map((e) => '${e.key + 1}. ${e.value.title}：${e.value.content}')
              .join('\n')),
          r.recordCount?.toString() ?? '',
        ].join(','));
      }
    }
    return buf.toString();
  }

  static String _combinedMarkdown(
      List<Record> records, List<InsightReportCache> insights) {
    final buf = StringBuffer();
    buf.writeln('# 瞬记 · 数据导出');
    buf.writeln();
    buf.writeln('> 导出时间：${_friendlyDate(DateTime.now())}');
    buf.writeln();

    // ── 目录 ──
    if (records.isNotEmpty && insights.isNotEmpty) {
      buf.writeln('## 目录');
      buf.writeln();
      buf.writeln('- [一、记录（${records.length} 条）](#一记录${records.length}-条)');
      buf.writeln('- [二、洞察报告（${insights.length} 份）](#二洞察报告${insights.length}-份)');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();

    // ── 记录部分 ──
    if (records.isNotEmpty) {
      buf.writeln('# 一、记录（${records.length} 条）');
      buf.writeln();
      _writeRecordStats(buf, records);

      final grouped = _groupRecordsByDate(records);
      for (final entry in grouped.entries) {
        buf.writeln('## ${entry.key}（${entry.value.length} 条）');
        buf.writeln();
        for (final r in entry.value) {
          _writeRecordMarkdown(buf, r);
        }
      }
    }

    // ── 洞察部分 ──
    if (insights.isNotEmpty) {
      buf.writeln('# 二、洞察报告（${insights.length} 份）');
      buf.writeln();
      for (final c in insights) {
        _writeInsightMarkdown(buf, c.report);
      }
    }
    return buf.toString();
  }

  static String fileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'json';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.markdown:
        return 'md';
    }
  }

  /// 生成内容预览片段（用于 UI 展示）
  static String contentPreview({
    required List<Record> records,
    required List<InsightReportCache> insights,
    required ExportFormat format,
    int maxLines = 12,
  }) {
    String full;
    switch (format) {
      case ExportFormat.json:
        // JSON 预览：只取前几条
        final previewRecords = records.take(1).toList();
        final previewInsights = insights.take(1).toList();
        final payload = <String, dynamic>{
          'exported_at': '2026-03-21T10:00:00.000',
        };
        if (previewRecords.isNotEmpty) {
          payload['records'] = ['...${records.length} items...'];
        }
        if (previewInsights.isNotEmpty) {
          payload['insights'] = ['...${insights.length} items...'];
        }
        full = const JsonEncoder.withIndent('  ').convert(payload);
        break;
      case ExportFormat.csv:
        final buf = StringBuffer();
        if (records.isNotEmpty) {
          buf.writeln('日期,时间,类型,标题,内容,...');
          for (final r in records.take(3)) {
            buf.writeln([
              _csvDate(r.createdAt),
              _csvTime(r.createdAt),
              _recordTypeName(r.type),
              _esc(r.title ?? ''),
              _esc(_truncate(r.transcription, 30)),
              '...',
            ].join(','));
          }
          if (records.length > 3) buf.writeln('... 共 ${records.length} 行');
        }
        if (insights.isNotEmpty) {
          if (records.isNotEmpty) buf.writeln();
          buf.writeln('周范围,报告日期,情绪概览,...');
          for (final c in insights.take(2)) {
            buf.writeln([
              _esc(c.report.weekRange),
              _csvDate(c.cachedAt),
              _esc(_truncate(c.report.emotionOverview.summary, 30)),
              '...',
            ].join(','));
          }
          if (insights.length > 2) buf.writeln('... 共 ${insights.length} 行');
        }
        full = buf.toString();
        break;
      case ExportFormat.markdown:
        final buf = StringBuffer();
        buf.writeln('# 瞬记 · 数据导出');
        buf.writeln();
        if (records.isNotEmpty) {
          buf.writeln('## ${_dateGroupKey(records.first.createdAt)}');
          buf.writeln();
          final first = records.first;
          final time =
              '${first.createdAt.hour.toString().padLeft(2, '0')}:${first.createdAt.minute.toString().padLeft(2, '0')}';
          buf.writeln('### $time　${_recordTypeName(first.type)}');
          buf.writeln();
          buf.writeln(_truncate(first.transcription, 80));
          buf.writeln();
          if (first.moods != null && first.moods!.isNotEmpty) {
            buf.writeln(
                '**情绪**：${first.moods!.take(3).map((m) => '`$m`').join(' ')}');
            buf.writeln();
          }
          if (records.length > 1) {
            buf.writeln('_... 还有 ${records.length - 1} 条记录_');
          }
        }
        if (insights.isNotEmpty) {
          buf.writeln();
          buf.writeln('## ${insights.first.report.weekRange}');
          buf.writeln();
          buf.writeln(
              '> ${_truncate(insights.first.report.emotionOverview.summary, 60)}');
          if (insights.length > 1) {
            buf.writeln();
            buf.writeln('_... 还有 ${insights.length - 1} 份报告_');
          }
        }
        full = buf.toString();
        break;
    }

    // 截断到 maxLines
    final lines = full.split('\n');
    if (lines.length <= maxLines) return full;
    return '${lines.take(maxLines).join('\n')}\n...';
  }

  // ═══════════════════════════════════════════════════
  //  Private helpers — Markdown
  // ═══════════════════════════════════════════════════

  /// 写入记录统计摘要
  static void _writeRecordStats(StringBuffer buf, List<Record> records) {
    // 统计类型分布
    final quickNotes =
        records.where((r) => r.type == RecordType.quickNote).length;
    final journals =
        records.where((r) => r.type == RecordType.journal).length;
    final weeklies =
        records.where((r) => r.type == RecordType.weekly).length;

    // 统计情绪词频
    final moodFreq = <String, int>{};
    for (final r in records) {
      for (final m in r.moods ?? <String>[]) {
        moodFreq[m] = (moodFreq[m] ?? 0) + 1;
      }
    }
    // 取前 8 个高频情绪
    final topMoods = moodFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    buf.writeln('| 统计项 | 数据 |');
    buf.writeln('|--------|------|');
    buf.writeln('| 总记录数 | ${records.length} 条 |');

    final typeParts = <String>[];
    if (quickNotes > 0) typeParts.add('碎片 $quickNotes');
    if (journals > 0) typeParts.add('日记 $journals');
    if (weeklies > 0) typeParts.add('周记 $weeklies');
    if (typeParts.isNotEmpty) {
      buf.writeln('| 类型分布 | ${typeParts.join(' / ')} |');
    }

    if (records.isNotEmpty) {
      final first = records.last.createdAt; // records may be newest-first
      final last = records.first.createdAt;
      final earlier = first.isBefore(last) ? first : last;
      final later = first.isBefore(last) ? last : first;
      buf.writeln(
          '| 时间跨度 | ${_shortDate(earlier)} ~ ${_shortDate(later)} |');
    }

    if (topMoods.isNotEmpty) {
      final moodTags = topMoods
          .take(8)
          .map((e) => '${e.key}(${e.value})')
          .join('、');
      buf.writeln('| 高频情绪 | $moodTags |');
    }

    buf.writeln();
  }

  static Map<String, List<Record>> _groupRecordsByDate(List<Record> records) {
    final grouped = <String, List<Record>>{};
    for (final r in records) {
      final key = _dateGroupKey(r.createdAt);
      (grouped[key] ??= []).add(r);
    }
    return grouped;
  }

  static void _writeRecordMarkdown(StringBuffer buf, Record r) {
    final time =
        '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
    final typeLabel = _recordTypeName(r.type);

    // 标题行：时间 + 类型 + 可选时长
    final durationStr = r.duration != null
        ? '　⏱ ${_formatDuration(r.duration!)}'
        : '';
    buf.writeln('### $time　$typeLabel$durationStr');
    buf.writeln();

    if (r.title != null && r.title!.isNotEmpty) {
      buf.writeln('**${r.title}**');
      buf.writeln();
    }

    buf.writeln(r.transcription);
    buf.writeln();

    // 情绪 & 需求标签行
    final hasMoods = r.moods != null && r.moods!.isNotEmpty;
    final hasNeeds = r.needs != null && r.needs!.isNotEmpty;
    if (hasMoods || hasNeeds) {
      final tags = <String>[];
      if (hasMoods) {
        tags.addAll(r.moods!.map((m) => '`$m`'));
      }
      if (hasNeeds) {
        tags.add('·');
        tags.addAll(r.needs!.map((n) => '`$n`'));
      }
      buf.writeln(tags.join(' '));
      buf.writeln();
    }

    // NVC 分析 — 直接展示，不折叠
    if (r.nvc != null) {
      buf.writeln('#### NVC 分析');
      buf.writeln();

      buf.writeln('| 维度 | 内容 |');
      buf.writeln('|------|------|');
      buf.writeln('| **观察** | ${_escapeMdTable(r.nvc!.observation)} |');

      if (r.nvc!.feelings.isNotEmpty) {
        final feelStr = r.nvc!.feelings
            .map((f) => '${f.feeling} ${'●' * (f.intensity.index + 1)}${'○' * (4 - f.intensity.index)}')
            .join('　');
        buf.writeln('| **感受** | $feelStr |');
      }

      if (r.nvc!.needs.isNotEmpty) {
        final needStr = r.nvc!.needs
            .map((n) => '**${n.need}**（${n.reason}）')
            .join('　');
        buf.writeln('| **需求** | $needStr |');
      }

      if (r.nvc!.request != null && r.nvc!.request!.isNotEmpty) {
        buf.writeln('| **请求** | ${_escapeMdTable(r.nvc!.request!)} |');
      }

      if (r.nvc!.insight != null && r.nvc!.insight!.isNotEmpty) {
        buf.writeln('| **洞察** | ${_escapeMdTable(r.nvc!.insight!)} |');
      }

      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();
  }

  static void _writeInsightMarkdown(StringBuffer buf, InsightReport r) {
    buf.writeln('## ${r.weekRange}');
    if (r.recordCount != null) {
      buf.writeln();
      buf.writeln('> 基于 ${r.recordCount} 条记录生成');
    }
    buf.writeln();

    // 情绪概览
    buf.writeln('### 情绪概览');
    buf.writeln();
    buf.writeln(r.emotionOverview.summary);
    buf.writeln();

    // 高频情境 — 表格形式
    if (r.highFrequencyEmotions.isNotEmpty) {
      buf.writeln('### 高频情境');
      buf.writeln();
      buf.writeln('| 时间 | 内容 |');
      buf.writeln('|------|------|');
      for (final e in r.highFrequencyEmotions) {
        buf.writeln('| ${_escapeMdTable(e.time)} | ${_escapeMdTable(e.content)} |');
      }
      buf.writeln();
    }

    // 模式假设
    buf.writeln('### 潜在需求');
    buf.writeln();
    buf.writeln('> ${r.patternHypothesis.text}');
    if (r.patternHypothesis.highlightTags.isNotEmpty) {
      buf.writeln();
      buf.writeln(r.patternHypothesis.highlightTags
          .map((t) => '`${t.key}: ${t.value}`')
          .join('　'));
    }
    buf.writeln();

    // 行动建议 — 编号列表
    if (r.actionSuggestions.isNotEmpty) {
      buf.writeln('### 行动建议');
      buf.writeln();
      for (var i = 0; i < r.actionSuggestions.length; i++) {
        final a = r.actionSuggestions[i];
        buf.writeln('${i + 1}. **${a.title}**');
        buf.writeln('   ${a.content}');
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln();
  }

  // ═══════════════════════════════════════════════════
  //  Private helpers — common
  // ═══════════════════════════════════════════════════

  static String _recordTypeName(RecordType type) {
    switch (type) {
      case RecordType.quickNote:
        return '碎片记录';
      case RecordType.journal:
        return '日记';
      case RecordType.weekly:
        return '周记';
    }
  }

  static String _csvDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _csvTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _friendlyDate(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日 '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _shortDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _dateGroupKey(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  static String _formatDuration(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }

  /// CSV 字段转义
  static String _esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Markdown 表格内容转义（将 `|` 替换为 `\|`，换行替换为空格）
  static String _escapeMdTable(String value) {
    return value.replaceAll('|', '\\|').replaceAll('\n', ' ');
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  static String _feelingsText(List<Feeling>? feelings) {
    if (feelings == null || feelings.isEmpty) return '';
    return feelings
        .map((f) => '${f.feeling}(${f.intensity.index + 1})')
        .join('、');
  }

  static String _needsText(List<Need>? needs) {
    if (needs == null || needs.isEmpty) return '';
    return needs.map((n) => '${n.need}（${n.reason}）').join('、');
  }
}
