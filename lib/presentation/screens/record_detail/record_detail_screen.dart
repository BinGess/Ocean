/// 记录详情页面
/// 用于查看和编辑单条记录，支持添加标签和触发NVC分析
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';
import '../../../core/theme/app_typography.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_event.dart';
import '../../bloc/record/record_state.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/nvc_error_dialog.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../share/share_poster_screen.dart';
import '../settings/settings_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final Record record;

  const RecordDetailScreen({
    super.key,
    required this.record,
  });

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late List<String> _selectedMoods;
  late DateTime _selectedDateTime;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _selectedMoods = _normalizeMoodTags(widget.record.moods ?? const []);
    _selectedDateTime = widget.record.createdAt;
  }

  List<String> _normalizeMoodTags(List<String> source) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in source) {
      final parts = value
          .split(RegExp(r'[，,、；;|/\\\n]+'))
          .map((e) => e.trim())
          .map((e) => e.replaceFirst(RegExp(r'^\d+\s*[.、\-)\]]\s*'), ''))
          .where((e) => e.isNotEmpty);

      for (final part in parts) {
        if (seen.add(part)) {
          result.add(part);
        }
      }
    }

    return result;
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month;
    final day = dateTime.day;
    final period = dateTime.hour < 12 ? '上午' : '下午';
    final hour24 = dateTime.hour;
    final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month月$day日·$period$hour:$minute';
  }

  Record _buildDraftRecord({
    DateTime? updatedAt,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
    ProcessingMode? processingMode,
  }) {
    return widget.record.copyWith(
      createdAt: _selectedDateTime,
      updatedAt: updatedAt ?? widget.record.updatedAt,
      moods: moods ?? _selectedMoods,
      needs: needs ?? widget.record.needs,
      nvc: nvc ?? widget.record.nvc,
      processingMode: processingMode ?? widget.record.processingMode,
    );
  }

  Future<void> _pickRecordDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: '选择记录日期',
      cancelText: '取消',
      confirmText: '下一步',
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      helpText: '选择记录时间',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  /// 打开标签编辑对话框（和NVC一样）
  void _editMoodTags() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _TagEditDialog(
        title: '编辑我的感受',
        initialTags: _selectedMoods,
        suggestions: const [
          '焦虑',
          '开心',
          '平静',
          '愤怒',
          '悲伤',
          '好奇',
          '思考',
          '感激',
          '疲惫',
          '兴奋',
          '不适',
          '愧疚',
          '无奈'
        ],
        iconColor: const Color(0xFFFF9500),
        iconBgColor: const Color(0xFFFFF4E6),
        icon: Icons.favorite,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMoods = _normalizeMoodTags(result);
      });
      // TODO: 保存到数据库
    }
  }

  /// 触发NVC分析
  void _triggerNVCAnalysis() {
    setState(() {
      _isAnalyzing = true;
    });

    // 发送NVC分析请求
    context.read<RecordBloc>().add(
          RecordAnalyzeNVC(widget.record.transcription),
        );
  }

  /// 保存并关闭
  void _saveAndClose() {
    final updatedRecord = _buildDraftRecord(
      updatedAt: DateTime.now(),
    );
    context.read<RecordBloc>().add(RecordUpdate(record: updatedRecord));
    Navigator.of(context).pop();
  }

  /// 删除记录
  void _deleteRecord() async {
    final confirmed = await DeleteConfirmationDialog.show(context: context);
    if (!mounted || confirmed != true) {
      return;
    }

    // 删除记录
    context.read<RecordBloc>().add(
          RecordDelete(id: widget.record.id),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记录已删除')),
    );
    Navigator.of(context).pop(); // 关闭详情页
  }

  /// 处理AI授权请求
  Future<void> _handleAIAuthRequest(RecordState state) async {
    final result = await AIAuthDialog.show(context: context);
    if (!mounted) {
      return;
    }

    if (result == true) {
      // 用户同意授权
      await getIt<AIAuthService>().grant();
      if (!mounted) {
        return;
      }

      // 重新触发NVC分析
      if (state.transcription != null && state.transcription!.isNotEmpty) {
        context.read<RecordBloc>().add(
              RecordAnalyzeNVC(state.transcription!),
            );
        setState(() {
          _isAnalyzing = true;
        });
      }
    } else {
      // 用户拒绝授权
      _showAuthDeniedGuidance(context);
    }
  }

  /// 显示拒绝授权引导
  void _showAuthDeniedGuidance(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Expanded(
              child: Text('AI功能需要授权才能使用，您可在设置中开启'),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '去设置',
          textColor: const Color(0xFFC4A57B),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAnalyzedState(RecordState state) async {
    if (state.nvcAnalysis == null) {
      return;
    }

    final result = await NVCConfirmationModal.show(
      context: context,
      initialAnalysis: state.nvcAnalysis!,
      transcription: widget.record.transcription,
      record: _buildDraftRecord(),
      onRevert: () {
        // 还原为仅记录
      },
    );

    if (!mounted) {
      return;
    }

    if (result?.action == NVCModalAction.confirm) {
      final analysis = result?.analysis;
      if (analysis != null) {
        final selectedDateTime = result?.selectedDateTime;
        if (selectedDateTime != null) {
          setState(() {
            _selectedDateTime = selectedDateTime;
          });
        }
        final updatedRecord = _buildDraftRecord(
          nvc: analysis,
          processingMode: ProcessingMode.withNVC,
          moods: analysis.feelings.map((f) => f.feeling).toList(),
          needs: analysis.needs.map((n) => n.need).toList(),
          updatedAt: DateTime.now(),
        );
        context.read<RecordBloc>().add(
              RecordUpdate(record: updatedRecord),
            );
      }
      Navigator.of(context).pop();
      return;
    }

    if (result?.action == NVCModalAction.delete) {
      context.read<RecordBloc>().add(
            RecordDelete(id: widget.record.id),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已删除')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleAnalyzeErrorState() async {
    final action = await NVCErrorDialog.show(context: context);
    if (!mounted) {
      return;
    }

    if (action == NVCErrorAction.retry) {
      _triggerNVCAnalysis();
    } else if (action == NVCErrorAction.saveText) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listener: (context, state) {
        // 处理需要AI授权的情况
        if (state.status == RecordStatus.needsAIAuth && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.isCurrent ?? false) {
              _handleAIAuthRequest(state);
            }
          });
        } else if (state.status == RecordStatus.analyzed && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          _handleAnalyzedState(state);
        } else if (state.status == RecordStatus.error && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          _handleAnalyzeErrorState();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgCard,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _formatDateTime(_selectedDateTime),
            style: AppTypography.appBarTitle,
          ),
          centerTitle: true,
          actions: [
            // 分享按钮（使用 IconButton 保证在 AppBar 中始终可见）
            IconButton(
              onPressed: () => SharePosterScreen.show(
                context: context,
                record: _buildDraftRecord(),
              ),
              icon: const Icon(Icons.share_outlined,
                  size: 22, color: Color(0xFFC4A57B)),
              tooltip: '分享',
            ),
            const SizedBox(width: 4),
            // 删除按钮（使用 IconButton 避免与分享按钮争抢空间导致被挤出）
            IconButton(
              onPressed: _deleteRecord,
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: Color(0xFFFF3B30)),
              tooltip: '删除',
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
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
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saveAndClose,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                ),
                child: const Text(
                  '完成',
                  style: AppTypography.buttonLarge,
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickRecordDateTime,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7EFE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: Color(0xFFC4A57B),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(_selectedDateTime),
                              style: AppTypography.detailTitle.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '点击修改这条记录的日期和时间',
                              style: AppTypography.bodySecondary.copyWith(
                                color: AppColors.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSubtle,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // 转写文本区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgCardSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Text(
                  widget.record.transcription,
                  style: AppTypography.detailBody,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // 洞察标签
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    '洞察',
                    style: AppTypography.modalCaption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // 感受标签卡片
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF4E6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 16,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '我现在的感受',
                            style: AppTypography.detailTitle.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // 编辑按钮放在标题右侧
                        GestureDetector(
                          onTap: _editMoodTags,
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // "也许..."提示 + 标签
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '也许...',
                            style: AppTypography.tagLabel.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _selectedMoods.isEmpty
                              ? Text(
                                  '点击编辑添加感受',
                                  style: AppTypography.bodySecondary.copyWith(
                                    color: AppColors.textSubtle,
                                  ),
                                )
                              : Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: _selectedMoods.map((mood) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.border,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        mood,
                                        style: AppTypography.tagLabel,
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // NVC分析卡片
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
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
                    // 标题栏
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NVC分析',
                          style: AppTypography.detailTitle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.more_horiz,
                          color: AppColors.textSubtle,
                          size: 20,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // NVC分析按钮
                    GestureDetector(
                      onTap: _isAnalyzing ? null : _triggerNVCAnalysis,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.bgCardSecondary,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isAnalyzing ? '正在分析中...' : '让AI来分析你的情况',
                                style: AppTypography.bodySecondary.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            if (_isAnalyzing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.accent,
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

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// 标签编辑对话框（复用NVC的对话框逻辑）
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
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
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
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.detailTitle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // 已选标签
            if (_selectedTags.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
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
                            style: AppTypography.tagLabel.copyWith(
                              color: widget.iconColor,
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
              const SizedBox(height: AppSpacing.lg),
            ],

            // 建议标签
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '建议标签',
                      style: AppTypography.modalCaption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
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
                                  : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? widget.iconColor
                                    : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: AppTypography.tagLabel.copyWith(
                                color: isSelected
                                    ? widget.iconColor
                                    : AppColors.textSecondary,
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

            const SizedBox(height: AppSpacing.lg),

            // 自定义输入标题
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '自定义标签',
                style: AppTypography.modalCaption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // 自定义输入框
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.borderLight,
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
                      style: AppTypography.buttonMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        hintText: '输入并添加...',
                        hintStyle: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: widget.iconBgColor,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      child: InkWell(
                        onTap: _addCustomTag,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
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

            const SizedBox(height: AppSpacing.xl),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.bgCard,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: AppTypography.buttonMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _selectedTags),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                    ),
                    child: Text(
                      '完成',
                      style: AppTypography.buttonMedium.copyWith(
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
