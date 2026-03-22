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

class _ExportScreenState extends State<ExportScreen>
    with TickerProviderStateMixin {
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
  double _exportProgress = 0.0;
  // ─── 动画控制器 ────────────────────────────────
  late final AnimationController _successController;
  late final Animation<double> _successScale;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _loadCounts();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _progressController.dispose();
    super.dispose();
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

  /// 根据当前日期范围过滤后的记录数
  int get _filteredRecordCount => _filterByDate(_allRecords).length;

  /// 根据当前日期范围过滤后的洞察数
  int get _filteredInsightCount => _filterInsightsByDate(_allInsights).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
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
      body: _loadingCounts ? _buildLoadingState() : _buildContent(l10n),
    );
  }

  // ═══════════════════════════════════════════════
  //  Loading state
  // ═══════════════════════════════════════════════

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.exportLoadingData,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8B8B8B),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Main content
  // ═══════════════════════════════════════════════

  Widget _buildContent(AppLocalizations l10n) {
    // 无数据时的空状态
    if (_totalRecords == 0 && _totalInsights == 0) {
      return _buildEmptyState(l10n);
    }

    return Column(
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
    );
  }

  // ═══════════════════════════════════════════════
  //  Empty state
  // ═══════════════════════════════════════════════

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 40,
                color: Color(0xFFCCC5B9),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.exportEmptyTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exportEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8B8B8B),
                height: 1.5,
              ),
            ),
          ],
        ),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F3),
                borderRadius: BorderRadius.circular(12),
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
                      fontSize: 16,
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
            color:
                selected ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
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
              _buildRangeChip(
                  _DateRange.threeMonths, l10n.exportRange3Months),
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
            color:
                selected ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
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
          color:
              isCustom ? const Color(0xFFC4A57B) : const Color(0xFFF8F6F3),
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
      parts.add(l10n.exportPreviewRecords(_filteredRecordCount));
    }
    if (_includeInsights && _totalInsights > 0) {
      parts.add(l10n.exportPreviewInsights(_filteredInsightCount));
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
    final filteredRecords = _filterByDate(_allRecords);
    final filteredInsights = _filterInsightsByDate(_allInsights);
    final previewRecords =
        _includeRecords ? filteredRecords.take(5).toList() : <Record>[];
    final previewInsights = _includeInsights
        ? filteredInsights.take(2).toList()
        : <InsightReportCache>[];

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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  fontFamily:
                      _format == ExportFormat.json ? 'monospace' : null,
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
  //  Bottom export button (with progress & animation)
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
          child: _exporting
              ? _buildProgressButton(l10n)
              : ElevatedButton(
                  onPressed: _hasSelection ? _doExport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC4A57B),
                    disabledBackgroundColor: const Color(0xFFE0D8CD),
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
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

  /// 带进度条的导出按钮
  Widget _buildProgressButton(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFC4A57B),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 进度条背景
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return FractionallySizedBox(
                widthFactor: _exportProgress,
                alignment: Alignment.centerLeft,
                child: Container(
                  color: const Color(0xFFB8955F),
                ),
              );
            },
          ),
          // 文字
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.exportExporting((_exportProgress * 100).toInt()),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Export completion bottom sheet
  // ═══════════════════════════════════════════════

  void _showExportCompleteSheet({
    required AppLocalizations l10n,
    required File file,
    required int recordCount,
    required int insightCount,
  }) {
    _successController.forward(from: 0);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 28),

                // 成功动画图标
                ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 36,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 标题
                Text(
                  l10n.exportSuccess,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 8),

                // 摘要
                Text(
                  l10n.exportDone(recordCount, insightCount),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B8B8B),
                  ),
                ),
                const SizedBox(height: 8),

                // 文件信息
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _format == ExportFormat.markdown
                            ? Icons.article_outlined
                            : _format == ExportFormat.csv
                                ? Icons.table_chart_outlined
                                : Icons.data_object,
                        size: 18,
                        color: const Color(0xFF8B7D6B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.path.split('/').last,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5C5C5C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _fileSizeString(file),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B8B8B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 操作按钮行
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // 分享按钮
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _tryShareFile(context, file,
                                  text: l10n.exportShareText);
                            },
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text(l10n.exportActionShare),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC4A57B),
                              side: const BorderSide(
                                  color: Color(0xFFC4A57B), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 完成按钮
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC4A57B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.exportActionDone,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  //  Export logic (with progress updates)
  // ═══════════════════════════════════════════════

  Future<void> _doExport() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _exporting = true;
      _exportProgress = 0.0;
    });

    try {
      // Step 1: Filter data (10%)
      _updateProgress(0.1);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      List<Record> records =
          _includeRecords ? _filterByDate(_allRecords) : [];
      List<InsightReportCache> insights =
          _includeInsights ? _filterInsightsByDate(_allInsights) : [];

      if (records.isEmpty && insights.isEmpty) {
        _showToast(l10n.exportNoData);
        return;
      }

      // Step 2: Format data (40%)
      _updateProgress(0.4);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final content = ExportFormatter.combinedExport(
        records: records,
        insights: insights,
        format: _format,
      );

      // Step 3: Write file (70%)
      _updateProgress(0.7);
      final ext = ExportFormatter.fileExtension(_format);
      final file = await _writeFile(
        content: content,
        extension: ext,
      );

      // Step 4: Done (100%)
      _updateProgress(1.0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      setState(() => _exporting = false);

      // Show completion bottom sheet
      _showExportCompleteSheet(
        l10n: l10n,
        file: file,
        recordCount: records.length,
        insightCount: insights.length,
      );
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) {
        setState(() => _exporting = false);
        _showToast(l10n.exportFailed);
      }
    }
  }

  void _updateProgress(double value) {
    if (!mounted) return;
    setState(() {
      _exportProgress = value;
    });
    _progressController.forward();
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
            end: DateTime(_customEnd!.year, _customEnd!.month,
                _customEnd!.day, 23, 59, 59),
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
    final file =
        File('${directory.path}/mindflow_export_$timestamp.$extension');
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

  String _fileSizeString(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}
