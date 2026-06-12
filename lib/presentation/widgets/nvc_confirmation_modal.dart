import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/deep_analysis_local_service.dart';
import '../../core/services/pro_subscription_service.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/entities/deep_analysis_result.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/record.dart';
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
  late final ScrollController _deeperSupportScrollController;
  DeeperSupportType? _selectedDeeperSupportType;
  final List<DeepAnalysisResult> _deepAnalyses = [];

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
    final recommendedIndex = DeeperSupportType.values.indexOf(
      recommendedDeeperSupportType(
        transcription: widget.transcription,
        analysis: widget.initialAnalysis,
      ),
    );
    _deeperSupportScrollController = ScrollController(
      initialScrollOffset:
          recommendedIndex > 1 ? (recommendedIndex - 1) * 144.0 : 0,
    );
    unawaited(_loadSavedDeepAnalysis());
  }

  @override
  void dispose() {
    _deeperSupportScrollController.dispose();
    super.dispose();
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
    if (recordId == null || !getIt.isRegistered<DeepAnalysisLocalService>()) {
      return;
    }

    final saved = getIt<DeepAnalysisLocalService>().getForRecord(recordId);
    if (saved.isEmpty || !mounted) return;

    setState(() {
      _deepAnalyses
        ..clear()
        ..addAll(saved);
      final latest = saved.last;
      for (final type in DeeperSupportType.values) {
        if (type.name == latest.type) {
          _selectedDeeperSupportType = type;
          break;
        }
      }
    });
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

  Future<void> _handleViewDeeperSupport({
    required bool hasProAccess,
    required List<DeeperSupportRecommendation> recommendations,
  }) async {
    if (!hasProAccess) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
      );
      return;
    }

    if (_selectedDeeperSupportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('先选一个你想继续深入的方向'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedRecommendation = recommendations.firstWhere(
      (item) => item.type == _selectedDeeperSupportType,
    );
    await _openDeeperSupport(selectedRecommendation);
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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
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
                color: const Color(0xFFF5F5F5),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F0E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.transcription,
                          style: const TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '洞察',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildNVCCard(
                        context: context,
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
                      _buildNVCCard(
                        context: context,
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
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1,
                                    ),
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
                      _buildNVCCard(
                        context: context,
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
                      _buildNVCCard(
                        context: context,
                        icon: Icons.lightbulb_outline,
                        iconColor: const Color(0xFFFFB300),
                        iconBgColor: const Color(0xFFFFF8E1),
                        title: '行动 Tips',
                        content: Text(
                          _insight,
                          style: const TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        onEdit: _editInsight,
                      ),
                      if (_deepAnalyses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._deepAnalyses.asMap().entries.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: entry.key == _deepAnalyses.length - 1
                                      ? 0
                                      : 10,
                                ),
                                child: _buildDeepAnalysisSummary(entry.value),
                              ),
                            ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            '继续深入',
                            style: AppTypography.sectionTitle.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          if (!hasProAccess) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Pro',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8D6A3B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasProAccess
                            ? '选一个更贴近此刻的方向，我们再往下走一点。'
                            : '继续深入是 Pro 会员功能，解锁后可获得 5 种更深一层的帮助。',
                        style: AppTypography.sectionSubtle.copyWith(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDeeperSupportStrip(
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
                color: const Color(0xFFF5F5F5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _handleViewDeeperSupport(
                          hasProAccess: hasProAccess,
                          recommendations: recommendations,
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          hasProAccess ? '查看深入分析' : 'Pro 深入分析',
                          style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('nvc-confirm-complete-button'),
                        onPressed: _handleConfirm,
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
                          '完成',
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.textPrimary,
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

  Widget _buildNVCCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required Widget content,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行（标题+编辑按钮）
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // 编辑按钮放在标题右侧
              GestureDetector(
                onTap: onEdit,
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '也许...',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: content),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeeperSupportCard({
    required DeeperSupportRecommendation recommendation,
    required bool isRecommended,
    required bool isSelected,
    required bool hasProAccess,
  }) {
    return GestureDetector(
      onTap: () {
        if (!hasProAccess) {
          _openDeeperSupport(recommendation);
          return;
        }

        setState(() {
          _selectedDeeperSupportType = recommendation.type;
        });
      },
      child: SizedBox(
        width: 132,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isSelected)
              Positioned(
                top: 6,
                left: -2,
                right: -2,
                bottom: -2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFC9A979),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      recommendation.theorySource,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!hasProAccess)
              Positioned(
                top: 14,
                right: 8,
                child: Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            if (isSelected && hasProAccess)
              Positioned(
                top: 0,
                right: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC09A67),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC09A67).withValues(alpha: 0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              )
            else if (isRecommended)
              Positioned(
                top: 0,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    '推荐',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepAnalysisSummary(DeepAnalysisResult analysis) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
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
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '深入分析',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                analysis.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${analysis.methodLabel} · ${analysis.theorySource}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionSubtle.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                analysis.groundedUnderstanding,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF5A5148),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildDeeperSupportStrip({
    required List<DeeperSupportRecommendation> recommendations,
    required DeeperSupportType recommendedType,
    required bool hasProAccess,
  }) {
    return SizedBox(
      height: 106,
      child: ListView.separated(
        controller: _deeperSupportScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        itemCount: recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final recommendation = recommendations[index];
          return Opacity(
            opacity: hasProAccess ? 1 : 0.52,
            child: _buildDeeperSupportCard(
              recommendation: recommendation,
              isRecommended: recommendation.type == recommendedType,
              isSelected: recommendation.type == _selectedDeeperSupportType,
              hasProAccess: hasProAccess,
            ),
          );
        },
      ),
    );
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
