import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/deep_analysis_local_service.dart';
import '../../core/services/pro_subscription_service.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/entities/deep_analysis_result.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/record.dart';
import 'analysis/analysis_widgets.dart';
import 'delete_confirmation_dialog.dart';
import 'record_date_time_picker.dart';
import '../screens/intervention/deeper_support_screen.dart';
import '../screens/pro/pro_purchase_screen.dart';
import '../screens/share/share_poster_screen.dart';

class NVCConfirmationModal extends StatefulWidget {
  final NVCAnalysis initialAnalysis;
  final String transcription;
  final Function(NVCAnalysis, DateTime, List<DeepAnalysisResult>) onConfirm;
  final VoidCallback? onRevert;
  final Record? record; // 可选的完整记录，用于分享
  final DateTime? initialDateTime;

  const NVCConfirmationModal({
    super.key,
    required this.initialAnalysis,
    required this.transcription,
    required this.onConfirm,
    this.onRevert,
    this.record,
    this.initialDateTime,
  });

  @override
  State<NVCConfirmationModal> createState() => _NVCConfirmationModalState();

  static Future<NVCModalResult?> show({
    required BuildContext context,
    required NVCAnalysis initialAnalysis,
    required String transcription,
    VoidCallback? onRevert,
    Record? record,
    DateTime? initialDateTime,
  }) {
    return Navigator.of(context).push<NVCModalResult>(
      MaterialPageRoute(
        builder: (_) => NVCConfirmationModal(
          initialAnalysis: initialAnalysis,
          transcription: transcription,
          onConfirm: (analysis, selectedDateTime, deepAnalyses) =>
              Navigator.of(context).pop(
            NVCModalResult(
              action: NVCModalAction.confirm,
              analysis: analysis,
              selectedDateTime: selectedDateTime,
              deepAnalyses: deepAnalyses,
            ),
          ),
          onRevert: onRevert,
          record: record,
          initialDateTime: initialDateTime,
        ),
      ),
    );
  }
}

class _NVCConfirmationModalState extends State<NVCConfirmationModal> {
  late String _observation;
  late List<Feeling> _feelings;
  late List<Need> _needs;
  late String _insight;
  late DateTime _selectedDateTime;
  final List<DeepAnalysisResult> _deepAnalyses = [];

  /// 分析 Tab：0 = 基础分析，1 = 专业分析。
  int _activeAnalysisTab = 0;

  bool get _hasProAccess =>
      getIt.isRegistered<ProSubscriptionService>() &&
      getIt<ProSubscriptionService>().hasProFeatureAccess;

  @override
  void initState() {
    super.initState();
    _observation = _stripSquareBrackets(widget.initialAnalysis.observation);
    _feelings = _normalizeFeelings(widget.initialAnalysis.feelings);
    _needs = _normalizeNeeds(widget.initialAnalysis.needs);
    _insight = widget.initialAnalysis.request ??
        widget.initialAnalysis.insight ??
        '尝试在双方情绪平稳时，以"我"开头表达感受，而非指责。';
    _selectedDateTime = widget.initialDateTime ??
        widget.record?.createdAt ??
        widget.initialAnalysis.analyzedAt;
    unawaited(_loadSavedDeepAnalysis());
  }

  String _stripSquareBrackets(String value) {
    var text = value.trim();
    if (text.startsWith('[') && text.endsWith(']') && text.length >= 2) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  List<String> _splitTags(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'^[\[\(\{（【\s]+|[\]\)\}）】\s]+$'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll('"', '');

    if (cleaned.isEmpty) return [];

    return cleaned
        .split(RegExp(r'[，,、；;|/\\\n]+'))
        .map((e) => e.trim())
        .map((e) => e.replaceFirst(RegExp(r'^\d+\s*[.、\-)\]]\s*'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<Feeling> _normalizeFeelings(List<Feeling> source) {
    final seen = <String>{};
    final result = <Feeling>[];
    for (final item in source) {
      for (final token in _splitTags(item.feeling)) {
        if (seen.add(token)) {
          result.add(Feeling(feeling: token, intensity: item.intensity));
        }
      }
    }
    return result;
  }

  List<Need> _normalizeNeeds(List<Need> source) {
    final seen = <String>{};
    final result = <Need>[];
    for (final item in source) {
      for (final token in _splitTags(item.need)) {
        if (seen.add(token)) {
          result.add(Need(need: token, reason: item.reason));
        }
      }
    }
    return result;
  }

  void _handleConfirm() {
    final updatedAnalysis = widget.initialAnalysis.copyWith(
      observation: _observation,
      feelings: _feelings,
      needs: _needs,
      request: _insight,
      analyzedAt: DateTime.now(),
    );
    widget.onConfirm(
      updatedAnalysis,
      _selectedDateTime,
      List.unmodifiable(_deepAnalyses),
    );
  }

  Future<void> _loadSavedDeepAnalysis() async {
    final recordId = widget.record?.id;
    if (recordId == null) {
      return;
    }

    final saved = getIt.isRegistered<DeepAnalysisLocalService>()
        ? getIt<DeepAnalysisLocalService>().getForRecord(recordId)
        : const <DeepAnalysisResult>[];
    final merged = _mergeDeepAnalyses(
      widget.record?.deepAnalyses ?? const [],
      saved,
    );
    if (merged.isEmpty || !mounted) return;

    setState(() {
      _deepAnalyses
        ..clear()
        ..addAll(merged);
    });
  }

  List<DeepAnalysisResult> _mergeDeepAnalyses(
    List<DeepAnalysisResult> synced,
    List<DeepAnalysisResult> local,
  ) {
    final byType = <String, DeepAnalysisResult>{
      for (final item in synced) item.type: item,
    };
    for (final item in local) {
      byType[item.type] = item;
    }
    return byType.values.toList(growable: false);
  }

  Future<void> _pickRecordDateTime() async {
    final pickedDateTime = await showRecordDateTimePicker(
      context: context,
      initialDateTime: _selectedDateTime,
    );

    if (pickedDateTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = pickedDateTime;
    });
  }

  void _handleDelete() async {
    // 显示删除确认对话框
    final confirmed = await DeleteConfirmationDialog.show(context: context);
    if (!mounted || confirmed != true) {
      return;
    }

    Navigator.of(context).pop(
      NVCModalResult(action: NVCModalAction.delete),
    ); // 关闭NVC弹窗，返回删除动作
  }

  void _editObservation() async {
    final result = await _showEditDialog(
      title: '编辑事实观察',
      initialValue: _observation,
      iconColor: const Color(0xFF4CAF50),
      iconBgColor: const Color(0xFFE8F5E9),
      icon: Icons.remove_red_eye_outlined,
    );
    if (result != null) {
      setState(() => _observation = result);
    }
  }

  void _editInsight() async {
    final result = await _showEditDialog(
      title: '编辑行动 Tips',
      initialValue: _insight,
      iconColor: const Color(0xFFFFB300),
      iconBgColor: const Color(0xFFFFF8E1),
      icon: Icons.lightbulb_outline,
    );
    if (result != null) {
      setState(() => _insight = result);
    }
  }

  void _editFeelings() async {
    final result = await _showTagEditDialog(
      title: '编辑我的感受',
      initialTags: _feelings.map((f) => f.feeling).toList(),
      suggestions: ['焦虑', '开心', '平静', '愤怒', '悲伤', '好奇', '思考', '感激', '疲惫', '兴奋'],
      iconColor: const Color(0xFFFF9500),
      iconBgColor: const Color(0xFFFFF4E6),
      icon: Icons.favorite,
    );
    if (result != null) {
      setState(() {
        _feelings = _normalizeFeelings(result
            .map((tag) => Feeling(
                  feeling: tag,
                  intensity: IntensityLevel.medium,
                ))
            .toList());
      });
    }
  }

  void _editNeeds() async {
    final currentNeeds = _needs.map((n) => n.need).join('、');
    final result = await _showEditDialog(
      title: '编辑我的需要',
      initialValue: currentNeeds,
      iconColor: const Color(0xFF34C759),
      iconBgColor: const Color(0xFFE8F5E9),
      icon: Icons.spa_outlined,
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        final parsedNeeds = _splitTags(result)
            .map((need) => Need(need: need, reason: ''))
            .toList();
        _needs = _normalizeNeeds(parsedNeeds);
      });
    }
  }

  Future<String?> _showEditDialog({
    required String title,
    required String initialValue,
    required Color iconColor,
    required Color iconBgColor,
    required IconData icon,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 输入框
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4A4A4A),
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '请输入内容...',
                    hintStyle: TextStyle(
                      color: Color(0xFFB8B8B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>?> _showTagEditDialog({
    required String title,
    required List<String> initialTags,
    required List<String> suggestions,
    required Color iconColor,
    required Color iconBgColor,
    required IconData icon,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => _TagEditDialog(
        title: title,
        initialTags: initialTags,
        suggestions: suggestions,
        iconColor: iconColor,
        iconBgColor: iconBgColor,
        icon: icon,
      ),
    );
  }

  Future<void> _openDeeperSupport(
    DeeperSupportRecommendation recommendation,
  ) async {
    if (!mounted) return;

    if (_hasProAccess) {
      final result = await Navigator.of(context).push<DeepAnalysisResult>(
        MaterialPageRoute(
          builder: (_) => DeeperSupportScreen(
            analysis: recommendation.toResult(),
            // 传原始记录文本供智能体拆解；
            // 未配置智能体的方法会自动保持本地占位（详情页内部判断）
            transcription: widget.transcription,
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _upsertDeepAnalysis(result);
        });
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
    );
  }

  /// 取消：不应用本次 NVC 分析，回退为「仅记录」。
  /// 新建流程下 onRevert 会保存原始文本，详情页流程下为空操作。
  void _handleCancel() {
    widget.onRevert?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasProAccess = _hasProAccess;
    final recommendations = buildDeeperSupportRecommendations(
      transcription: widget.transcription,
      analysis: widget.initialAnalysis,
    );
    final recommendedType = recommendedDeeperSupportType(
      transcription: widget.transcription,
      analysis: widget.initialAnalysis,
    );

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: AppColors.bgPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  GestureDetector(
                    onTap: _pickRecordDateTime,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatRecordDateTime(
                              _selectedDateTime,
                              languageCode:
                                  Localizations.localeOf(context).languageCode,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF8B8B8B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: Color(0xFFB8B8B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.record != null) ...[
                        IconButton(
                          onPressed: () => SharePosterScreen.show(
                            context: context,
                            record: widget.record!.copyWith(
                              createdAt: _selectedDateTime,
                            ),
                          ),
                          icon: const Icon(
                            Icons.share_outlined,
                            size: 22,
                            color: AppColors.accent,
                          ),
                          tooltip: '分享',
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        onPressed: _handleDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 22,
                          color: Color(0xFFFF3B30),
                        ),
                        tooltip: '删除',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.bgPrimary,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranscriptionQuote(text: widget.transcription),
                      const SizedBox(height: 16),
                      AnalysisTabBar(
                        activeIndex: _activeAnalysisTab,
                        onChanged: (index) =>
                            setState(() => _activeAnalysisTab = index),
                      ),
                      const SizedBox(height: 16),
                      if (_activeAnalysisTab == 0)
                        _buildBasicTab()
                      else
                        _buildProfessionalTab(
                          recommendations: recommendations,
                          recommendedType: recommendedType,
                          hasProAccess: hasProAccess,
                        ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D4E3C).withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleCancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('nvc-confirm-complete-button'),
                        onPressed: _handleConfirm,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 基础分析 Tab：观察 / 感受 / 需要 / 行动 Tips 四张可编辑卡。
  Widget _buildBasicTab() {
    return Column(
      children: [
        NVCInfoCard(
          icon: Icons.remove_red_eye_outlined,
          iconColor: const Color(0xFF4CAF50),
          iconBgColor: const Color(0xFFE8F5E9),
          title: '事实观察',
          content: Text(
            _observation,
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          onEdit: _editObservation,
        ),
        const SizedBox(height: 12),
        NVCInfoCard(
          icon: Icons.favorite,
          iconColor: const Color(0xFFFF9500),
          iconBgColor: const Color(0xFFFFF4E6),
          title: '我现在的感受',
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feelings
                .map(
                  (f) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      f.feeling,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          onEdit: _editFeelings,
        ),
        const SizedBox(height: 12),
        NVCInfoCard(
          icon: Icons.spa_outlined,
          iconColor: const Color(0xFF34C759),
          iconBgColor: const Color(0xFFE8F5E9),
          title: '我需要',
          content: Text(
            _needs.map((n) => n.need).join('、'),
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          onEdit: _editNeeds,
        ),
        const SizedBox(height: 12),
        NVCInfoCard(
          icon: Icons.lightbulb_outline,
          iconColor: const Color(0xFFFFB300),
          iconBgColor: const Color(0xFFFFF8E1),
          title: '行动 Tips',
          showPrompt: false,
          content: NVCActionTipsContent(
            text: _insight,
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          onEdit: _editInsight,
        ),
      ],
    );
  }

  /// 专业分析 Tab：列表样式，推荐方法排在第一位并高亮。
  Widget _buildProfessionalTab({
    required List<DeeperSupportRecommendation> recommendations,
    required DeeperSupportType recommendedType,
    required bool hasProAccess,
  }) {
    // 已生成结果的方法不再出现在下方列表（避免与顶部摘要卡重复）。
    final generatedTypes = _deepAnalyses.map((item) => item.type).toSet();
    final available = recommendations
        .where((item) => !generatedTypes.contains(item.type.name))
        .toList();
    // 推荐方法置顶，其余保持原顺序。
    final ordered = [
      ...available.where((item) => item.type == recommendedType),
      ...available.where((item) => item.type != recommendedType),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已生成的深入分析结果（若有），置于列表顶部供回看。
        if (_deepAnalyses.isNotEmpty) ...[
          ..._deepAnalyses.map(
            (analysis) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DeepAnalysisSummaryCard(
                analysis: analysis,
                onTap: () => _reviewDeepAnalysis(analysis),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          _professionalHint(
              hasProAccess: hasProAccess, hasMore: ordered.isNotEmpty),
          style: AppTypography.sectionSubtle.copyWith(
            color: AppColors.textMuted,
            height: 1.45,
          ),
        ),
        if (ordered.isNotEmpty) const SizedBox(height: 12),
        ...ordered.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnalysisMethodRow(
              recommendation: item,
              isRecommended: item.type == recommendedType,
              hasProAccess: hasProAccess,
              onTap: () => _openDeeperSupport(item),
            ),
          ),
        ),
      ],
    );
  }

  String _professionalHint(
      {required bool hasProAccess, required bool hasMore}) {
    if (!hasProAccess) {
      return '专业分析是 Pro 会员功能，解锁后可获得 5 种更深一层的帮助。';
    }
    if (!hasMore) {
      return '这条记录适合的方向，你都走过一遍了。需要时随时回看上面的结果。';
    }
    return '选一个更贴近此刻的方向，我们再往下走一点。';
  }

  Future<void> _reviewDeepAnalysis(DeepAnalysisResult analysis) async {
    final result = await Navigator.of(context).push<DeepAnalysisResult>(
      MaterialPageRoute(
        builder: (_) => DeeperSupportScreen(analysis: analysis),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _upsertDeepAnalysis(result);
      });
    }
  }

  void _upsertDeepAnalysis(DeepAnalysisResult result) {
    final existingIndex = _deepAnalyses.indexWhere(
      (item) => item.type == result.type,
    );
    if (existingIndex == -1) {
      _deepAnalyses.add(result);
      return;
    }
    _deepAnalyses[existingIndex] = result;
  }
}

/// 标签编辑对话框
class _TagEditDialog extends StatefulWidget {
  final String title;
  final List<String> initialTags;
  final List<String> suggestions;
  final Color iconColor;
  final Color iconBgColor;
  final IconData icon;

  const _TagEditDialog({
    required this.title,
    required this.initialTags,
    required this.suggestions,
    required this.iconColor,
    required this.iconBgColor,
    required this.icon,
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late List<String> _selectedTags;
  final TextEditingController _customTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final customTag = _customTagController.text.trim();
    if (customTag.isNotEmpty && !_selectedTags.contains(customTag)) {
      setState(() {
        _selectedTags.add(customTag);
        _customTagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 已选标签
            if (_selectedTags.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.iconColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _toggleTag(tag),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: widget.iconColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 建议标签
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '建议标签',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.suggestions.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () => _toggleTag(tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.iconBgColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? widget.iconColor
                                    : const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? widget.iconColor
                                    : const Color(0xFF4A4A4A),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 自定义输入标题
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '自定义标签',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 自定义输入框
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE8E8E8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customTagController,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        hintText: '输入并添加...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: widget.iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _addCustomTag,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            color: widget.iconColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _selectedTags),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// NVC弹窗动作枚举
enum NVCModalAction {
  confirm, // 确认保存
  delete, // 删除记录
}

/// NVC弹窗返回结果
class NVCModalResult {
  final NVCModalAction action;
  final NVCAnalysis? analysis;
  final DateTime? selectedDateTime;
  final List<DeepAnalysisResult> deepAnalyses;

  NVCModalResult({
    required this.action,
    this.analysis,
    this.selectedDateTime,
    this.deepAnalyses = const [],
  });
}
