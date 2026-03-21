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

  static String recordsToCsv(List<Record> records) {
    final buf = StringBuffer();
    // Header
    buf.writeln(
      '日期,类型,内容,情绪标签,需求标签,NVC观察,NVC感受,NVC需求,NVC请求,NVC洞察',
    );
    for (final r in records) {
      buf.writeln([
        _csvDate(r.createdAt),
        _recordTypeName(r.type),
        _csvEscape(r.title ?? _truncate(r.transcription, 200)),
        _csvEscape(r.moods?.join('、') ?? ''),
        _csvEscape(r.needs?.join('、') ?? ''),
        _csvEscape(r.nvc?.observation ?? ''),
        _csvEscape(_feelingsText(r.nvc?.feelings)),
        _csvEscape(_needsText(r.nvc?.needs)),
        _csvEscape(r.nvc?.request ?? ''),
        _csvEscape(r.nvc?.insight ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static String insightsToCsv(List<InsightReportCache> caches) {
    final buf = StringBuffer();
    buf.writeln('周范围,情绪概览,高频情境,模式假设,行动建议');
    for (final c in caches) {
      final r = c.report;
      buf.writeln([
        _csvEscape(r.weekRange),
        _csvEscape(_truncate(r.emotionOverview.summary, 300)),
        _csvEscape(r.highFrequencyEmotions
            .map((e) => '${e.time}: ${e.content}')
            .join('; ')),
        _csvEscape(r.patternHypothesis.text),
        _csvEscape(
            r.actionSuggestions.map((a) => '${a.title}: ${a.content}').join('; ')),
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
    buf.writeln('---');
    buf.writeln();

    // Group by date
    final grouped = <String, List<Record>>{};
    for (final r in records) {
      final key = _dateGroupKey(r.createdAt);
      (grouped[key] ??= []).add(r);
    }

    for (final entry in grouped.entries) {
      buf.writeln('## ${entry.key}');
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
        final buf = StringBuffer();
        if (records.isNotEmpty) {
          buf.writeln('=== 记录 ===');
          buf.write(recordsToCsv(records));
          buf.writeln();
        }
        if (insights.isNotEmpty) {
          buf.writeln('=== 洞察报告 ===');
          buf.write(insightsToCsv(insights));
        }
        return buf.toString();
      case ExportFormat.markdown:
        final buf = StringBuffer();
        buf.writeln('# 瞬记 · 数据导出');
        buf.writeln();
        buf.writeln('> 导出时间：${_friendlyDate(DateTime.now())}');
        buf.writeln();
        buf.writeln('---');
        buf.writeln();
        if (records.isNotEmpty) {
          buf.writeln('# 一、记录（${records.length} 条）');
          buf.writeln();
          final grouped = <String, List<Record>>{};
          for (final r in records) {
            final key = _dateGroupKey(r.createdAt);
            (grouped[key] ??= []).add(r);
          }
          for (final entry in grouped.entries) {
            buf.writeln('## ${entry.key}');
            buf.writeln();
            for (final r in entry.value) {
              _writeRecordMarkdown(buf, r);
            }
          }
        }
        if (insights.isNotEmpty) {
          buf.writeln('# 二、洞察报告（${insights.length} 份）');
          buf.writeln();
          for (final c in insights) {
            _writeInsightMarkdown(buf, c.report);
          }
        }
        return buf.toString();
    }
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

  // ─── Private helpers ────────────────────────────────

  static void _writeRecordMarkdown(StringBuffer buf, Record r) {
    final time =
        '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
    final typeLabel = _recordTypeName(r.type);

    buf.writeln('### $time　$typeLabel');
    buf.writeln();

    if (r.title != null && r.title!.isNotEmpty) {
      buf.writeln('**${r.title}**');
      buf.writeln();
    }

    buf.writeln(r.transcription);
    buf.writeln();

    if (r.moods != null && r.moods!.isNotEmpty) {
      buf.writeln('**情绪**：${r.moods!.map((m) => '`$m`').join(' ')}');
      buf.writeln();
    }

    if (r.needs != null && r.needs!.isNotEmpty) {
      buf.writeln('**需求**：${r.needs!.map((n) => '`$n`').join(' ')}');
      buf.writeln();
    }

    if (r.nvc != null) {
      buf.writeln('<details><summary>NVC 分析</summary>');
      buf.writeln();
      buf.writeln('- **观察**：${r.nvc!.observation}');
      if (r.nvc!.feelings.isNotEmpty) {
        buf.writeln(
            '- **感受**：${r.nvc!.feelings.map((f) => '${f.feeling}(${f.intensity.index + 1})').join('、')}');
      }
      if (r.nvc!.needs.isNotEmpty) {
        buf.writeln(
            '- **需求**：${r.nvc!.needs.map((n) => '${n.need}（${n.reason}）').join('、')}');
      }
      if (r.nvc!.request != null) {
        buf.writeln('- **请求**：${r.nvc!.request}');
      }
      if (r.nvc!.insight != null) {
        buf.writeln('- **洞察**：${r.nvc!.insight}');
      }
      buf.writeln();
      buf.writeln('</details>');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();
  }

  static void _writeInsightMarkdown(StringBuffer buf, InsightReport r) {
    buf.writeln('## ${r.weekRange}');
    buf.writeln();

    buf.writeln('### 情绪概览');
    buf.writeln();
    buf.writeln(r.emotionOverview.summary);
    buf.writeln();

    if (r.highFrequencyEmotions.isNotEmpty) {
      buf.writeln('### 高频情境');
      buf.writeln();
      for (final e in r.highFrequencyEmotions) {
        buf.writeln('- **${e.time}**：${e.content}');
      }
      buf.writeln();
    }

    buf.writeln('### 潜在需求');
    buf.writeln();
    buf.writeln(r.patternHypothesis.text);
    buf.writeln();

    if (r.actionSuggestions.isNotEmpty) {
      buf.writeln('### 行动建议');
      buf.writeln();
      for (final a in r.actionSuggestions) {
        buf.writeln('- **${a.title}**：${a.content}');
      }
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();
  }

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
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _friendlyDate(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日 '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _dateGroupKey(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
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
