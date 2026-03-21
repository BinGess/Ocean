import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/export_formatter.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/insight_report_cache.dart';
import '../../../domain/repositories/insight_repository.dart';
import '../../../domain/repositories/record_repository.dart';
import '../../../l10n/app_localizations.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

/// 日期范围预设
enum _DateRange { week, month, threeMonths, all, custom }

class _ExportScreenState extends State<ExportScreen> {
  // ─── 数据选择 ──────────────────────────────────
  bool _includeRecords = true;
  bool _includeInsights = true;

  // ─── 格式选择 ──────────────────────────────────
  ExportFormat _format = ExportFormat.markdown;

  // ─── 日期范围 ──────────────────────────────────
  _DateRange _dateRange = _DateRange.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  // ─── 数据（进入页面时加载）────────────────────
  List<Record> _allRecords = [];
  List<InsightReportCache> _allInsights = [];
  int _totalRecords = 0;
  int _totalInsights = 0;
  bool _loadingCounts = true;

  // ─── 导出状态 ──────────────────────────────────
  bool _exporting = false;
  bool _exportSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final recordRepo = getIt<RecordRepository>();
      final insightRepo = getIt<InsightRepository>();
      final records = await recordRepo.getAllRecords();
      final insights = await insightRepo.getAllCachedInsightReports();
      if (mounted) {
        setState(() {
          _allRecords = records;
          _allInsights = insights;
          _totalRecords = records.length;
          _totalInsights = insights.length;
          _loadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  bool get _hasSelection => _includeRecords || _includeInsights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.export,
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loadingCounts
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── 1. 选择导出内容 ───────────
                      _buildSectionHeader(l10n.exportSelectContent),
                      const SizedBox(height: 8),
                      _buildDataCard(),
                      const SizedBox(height: 20),

                      // ── 2. 选择导出格式 ───────────
                      _buildSectionHeader(l10n.exportSelectFormat),
                      const SizedBox(height: 8),
                      _buildFormatSelector(),
                      const SizedBox(height: 20),

                      // ── 3. 日期范围 ──────────────
                      _buildSectionHeader(l10n.exportDateRange),
                      const SizedBox(height: 8),
                      _buildDateRangeSelector(l10n),
                      const SizedBox(height: 20),

                      // ── 4. 导出预览 ──────────────
                      _buildPreviewCard(l10n),
                      const SizedBox(height: 20),

                      // ── 5. 内容预览 ──────────────
                      if (_hasSelection) ...[
                        _buildSectionHeader(l10n.exportContentPreview),
                        const SizedBox(height: 8),
                        _buildContentSample(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── 底部导出按钮 ──────────────────
                _buildExportButton(l10n),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Section header
  // ═══════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B7D6B),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  1. Data selection card
  // ═══════════════════════════════════════════════

  Widget _buildDataCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildCheckTile(
            icon: Icons.description_outlined,
            title: l10n.exportRecords,
            subtitle: l10n.exportRecordsCount(_totalRecords),
            value: _includeRecords,
            enabled: _totalRecords > 0,
            onChanged: (v) => setState(() => _includeRecords = v),
          ),
          const Divider(height: 1, indent: 56),
          _buildCheckTile(
            icon: Icons.auto_awesome_outlined,
            title: l10n.exportInsights,
            subtitle: l10n.exportInsightsCount(_totalInsights),
            value: _includeInsights,
            enabled: _totalInsights > 0,
            onChanged: (v) => setState(() => _includeInsights = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF8B7D6B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFB0B0B0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? const Color(0xFF8B8B8B)
                          : const Color(0xFFCCCCCC),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value && enabled,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                activeColor: const Color(0xFFC4A57B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(
                  color: enabled
                      ? const Color(0xFFCCC5B9)
                      : const Color(0xFFE0E0E0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  2. Format selector
  // ═══════════════════════════════════════════════

  Widget _buildFormatSelector() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildFormatChip(
            format: ExportFormat.markdown,
            label: 'Markdown',
            icon: Icons.article_outlined,
          ),
          const SizedBox(width: 8),
          _buildFormatChip(
            format: ExportFormat.csv,
            label: 'CSV',
            icon: Icons.table_chart_outlined,
          ),
          const SizedBox(width: 8),
          _buildFormatChip(
            format: ExportFormat.json,
            label: 'JSON',
            icon: Icons.data_object,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip({
    required ExportFormat format,
    required String label,
    required IconData icon,
  }) {
    final selected = _format == format;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC4A57B)
                  : const Color(0xFFE8E4DF),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : const Color(0xFF8B7D6B),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF5C5C5C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDescription(format),
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : const Color(0xFFAAAAAA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDescription(ExportFormat format) {
    final l10n = AppLocalizations.of(context)!;
    switch (format) {
      case ExportFormat.markdown:
        return l10n.exportFormatMarkdownDesc;
      case ExportFormat.csv:
        return l10n.exportFormatCsvDesc;
      case ExportFormat.json:
        return l10n.exportFormatJsonDesc;
    }
  }

  // ═══════════════════════════════════════════════
  //  3. Date range selector
  // ═══════════════════════════════════════════════

  Widget _buildDateRangeSelector(AppLocalizations l10n) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _buildRangeChip(_DateRange.week, l10n.exportRange7Days),
              const SizedBox(width: 8),
              _buildRangeChip(_DateRange.month, l10n.exportRange30Days),
              const SizedBox(width: 8),
              _buildRangeChip(_DateRange.threeMonths, l10n.exportRange3Months),
              const SizedBox(width: 8),
              _buildRangeChip(_DateRange.all, l10n.exportRangeAll),
            ],
          ),
          const SizedBox(height: 8),
          _buildCustomRangeRow(l10n),
        ],
      ),
    );
  }

  Widget _buildRangeChip(_DateRange range, String label) {
    final selected = _dateRange == range;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dateRange = range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC4A57B)
                  : const Color(0xFFE8E4DF),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF5C5C5C),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRangeRow(AppLocalizations l10n) {
    final isCustom = _dateRange == _DateRange.custom;
    return GestureDetector(
      onTap: () => _pickCustomRange(l10n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isCustom ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom
                ? const Color(0xFFC4A57B)
                : const Color(0xFFE8E4DF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: isCustom ? Colors.white : const Color(0xFF8B7D6B),
            ),
            const SizedBox(width: 6),
            Text(
              isCustom && _customStart != null && _customEnd != null
                  ? '${_fmtShortDate(_customStart!)} ~ ${_fmtShortDate(_customEnd!)}'
                  : l10n.exportCustomRange,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCustom ? FontWeight.w600 : FontWeight.w500,
                color: isCustom ? Colors.white : const Color(0xFF5C5C5C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomRange(AppLocalizations l10n) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC4A57B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C2C2C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = _DateRange.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  // ═══════════════════════════════════════════════
  //  4. Preview card
  // ═══════════════════════════════════════════════

  Widget _buildPreviewCard(AppLocalizations l10n) {
    final ext = ExportFormatter.fileExtension(_format);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined,
                  size: 18, color: Color(0xFF8B7D6B)),
              const SizedBox(width: 6),
              Text(
                l10n.exportPreview,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B7D6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPreviewRow(
            l10n.exportPreviewContent,
            _previewContentText(l10n),
          ),
          const SizedBox(height: 6),
          _buildPreviewRow(
            l10n.exportPreviewFormat,
            '${_format.name.toUpperCase()} (.$ext)',
          ),
          const SizedBox(height: 6),
          _buildPreviewRow(
            l10n.exportPreviewRange,
            _previewRangeText(l10n),
          ),
          const SizedBox(height: 6),
          _buildPreviewRow(
            l10n.exportPreviewFile,
            'mindflow_export.$ext',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8B8B8B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C2C),
            ),
          ),
        ),
      ],
    );
  }

  String _previewContentText(AppLocalizations l10n) {
    final parts = <String>[];
    if (_includeRecords && _totalRecords > 0) {
      parts.add(l10n.exportPreviewRecords(_totalRecords));
    }
    if (_includeInsights && _totalInsights > 0) {
      parts.add(l10n.exportPreviewInsights(_totalInsights));
    }
    if (parts.isEmpty) return l10n.exportNoSelection;
    return parts.join(' + ');
  }

  String _previewRangeText(AppLocalizations l10n) {
    switch (_dateRange) {
      case _DateRange.week:
        return l10n.exportRange7Days;
      case _DateRange.month:
        return l10n.exportRange30Days;
      case _DateRange.threeMonths:
        return l10n.exportRange3Months;
      case _DateRange.all:
        return l10n.exportRangeAll;
      case _DateRange.custom:
        if (_customStart != null && _customEnd != null) {
          return '${_fmtShortDate(_customStart!)} ~ ${_fmtShortDate(_customEnd!)}';
        }
        return l10n.exportCustomRange;
    }
  }

  // ═══════════════════════════════════════════════
  //  5. Content sample preview
  // ═══════════════════════════════════════════════

  Widget _buildContentSample() {
    final previewRecords = _includeRecords ? _allRecords.take(5).toList() : <Record>[];
    final previewInsights =
        _includeInsights ? _allInsights.take(2).toList() : <InsightReportCache>[];

    if (previewRecords.isEmpty && previewInsights.isEmpty) {
      return const SizedBox.shrink();
    }

    final sampleText = ExportFormatter.contentPreview(
      records: previewRecords,
      insights: previewInsights,
      format: _format,
    );

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 模拟文件标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F6F3),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8E4DF), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _format == ExportFormat.markdown
                      ? Icons.article_outlined
                      : _format == ExportFormat.csv
                          ? Icons.table_chart_outlined
                          : Icons.data_object,
                  size: 15,
                  color: const Color(0xFF8B7D6B),
                ),
                const SizedBox(width: 6),
                Text(
                  'mindflow_export.${ExportFormatter.fileExtension(_format)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8B7D6B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4A57B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _format.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC4A57B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 内容预览区
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Text(
                sampleText,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontFamily: _format == ExportFormat.json ? 'monospace' : null,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Bottom export button
  // ═══════════════════════════════════════════════

  Widget _buildExportButton(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _hasSelection && !_exporting ? _doExport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC4A57B),
              disabledBackgroundColor: const Color(0xFFE0D8CD),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _exporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _exportSuccess
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.exportSuccess,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        l10n.exportButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Export logic
  // ═══════════════════════════════════════════════

  Future<void> _doExport() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _exporting = true;
      _exportSuccess = false;
    });

    try {
      // 1. Use cached data, apply filters
      List<Record> records = _includeRecords
          ? _filterByDate(_allRecords)
          : [];
      List<InsightReportCache> insights = _includeInsights
          ? _filterInsightsByDate(_allInsights)
          : [];

      if (records.isEmpty && insights.isEmpty) {
        _showToast(l10n.exportNoData);
        return;
      }

      // 2. Format
      final content = ExportFormatter.combinedExport(
        records: records,
        insights: insights,
        format: _format,
      );

      // 3. Write file
      final ext = ExportFormatter.fileExtension(_format);
      final file = await _writeFile(
        content: content,
        extension: ext,
      );

      // 4. Share
      if (!mounted) return;
      final shared = await _tryShareFile(context, file, text: l10n.exportShareText);

      if (mounted) {
        setState(() => _exportSuccess = true);
        final recordCount = records.length;
        final insightCount = insights.length;
        _showToast(shared
            ? l10n.exportDone(recordCount, insightCount)
            : l10n.exportSavedLocal(file.path));

        // Reset success indicator after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _exportSuccess = false);
        });
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) _showToast(l10n.exportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<Record> _filterByDate(List<Record> records) {
    final range = _resolvedDateRange();
    if (range == null) return records;
    return records
        .where((r) =>
            !r.createdAt.isBefore(range.start) &&
            !r.createdAt.isAfter(range.end))
        .toList();
  }

  List<InsightReportCache> _filterInsightsByDate(
      List<InsightReportCache> caches) {
    final range = _resolvedDateRange();
    if (range == null) return caches;
    return caches
        .where((c) =>
            !c.cachedAt.isBefore(range.start) &&
            !c.cachedAt.isAfter(range.end))
        .toList();
  }

  DateTimeRange? _resolvedDateRange() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_dateRange) {
      case _DateRange.week:
        return DateTimeRange(
          start: endOfDay.subtract(const Duration(days: 7)),
          end: endOfDay,
        );
      case _DateRange.month:
        return DateTimeRange(
          start: endOfDay.subtract(const Duration(days: 30)),
          end: endOfDay,
        );
      case _DateRange.threeMonths:
        return DateTimeRange(
          start: endOfDay.subtract(const Duration(days: 90)),
          end: endOfDay,
        );
      case _DateRange.all:
        return null;
      case _DateRange.custom:
        if (_customStart != null && _customEnd != null) {
          return DateTimeRange(
            start: _customStart!,
            end: DateTime(
                _customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59),
          );
        }
        return null;
    }
  }

  Future<File> _writeFile({
    required String content,
    required String extension,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final file = File('${directory.path}/mindflow_export_$timestamp.$extension');
    await file.writeAsString(content);
    return file;
  }

  Future<bool> _tryShareFile(BuildContext context, File file,
      {String? text}) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        sharePositionOrigin: origin,
      );
      return true;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _fmtShortDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}
