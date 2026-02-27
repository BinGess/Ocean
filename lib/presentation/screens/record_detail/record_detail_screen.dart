/// 记录详情页面
/// 用于查看和编辑单条记录，支持添加标签和触发NVC分析
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
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
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _selectedMoods = _normalizeMoodTags(widget.record.moods ?? const []);
  }

  List<String> _normalizeMoodTags(List<String> source) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in source) {
      final parts = value
          .split(RegExp(r'[、,，;；/|\n]+'))
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
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month月$day日·$period$hour:$minute';
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

  /// 确认情绪标签
  void _confirmMoods() {
    // TODO: 保存更新的moods到数据库
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('感受已确认'),
        duration: Duration(milliseconds: 800),
      ),
    );
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
    // TODO: 保存更新的moods到数据库
    Navigator.of(context).pop();
  }

  /// 删除记录
  void _deleteRecord() async {
    final confirmed = await DeleteConfirmationDialog.show(context: context);
    if (confirmed == true) {
      // 删除记录
      context.read<RecordBloc>().add(
            RecordDelete(id: widget.record.id),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已删除')),
      );
      Navigator.of(context).pop(); // 关闭详情页
    }
  }

  /// 处理AI授权请求
  Future<void> _handleAIAuthRequest(
      BuildContext context, RecordState state) async {
    final result = await AIAuthDialog.show(context: context);

    if (result == true) {
      // 用户同意授权
      await getIt<AIAuthService>().grant();

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
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            const Expanded(
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
              _handleAIAuthRequest(context, state);
            }
          });
        } else if (state.status == RecordStatus.analyzed && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          // 显示NVC确认弹窗
          if (state.nvcAnalysis != null) {
            NVCConfirmationModal.show(
              context: context,
              initialAnalysis: state.nvcAnalysis!,
              transcription: widget.record.transcription,
              onRevert: () {
                // 还原为仅记录
              },
            ).then((result) {
              if (result?.action == NVCModalAction.confirm) {
                // TODO: 保存NVC分析结果到记录
                Navigator.of(context).pop(); // 关闭详情页
              } else if (result?.action == NVCModalAction.delete) {
                // 用户选择了删除，删除这条记录
                context.read<RecordBloc>().add(
                      RecordDelete(id: widget.record.id),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记录已删除')),
                );
                Navigator.of(context).pop(); // 关闭详情页
              }
            });
          }
        } else if (state.status == RecordStatus.error && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          // 显示友好的错误对话框
          NVCErrorDialog.show(context: context).then((action) {
            if (action == NVCErrorAction.retry) {
              // 立即重试NVC分析
              _triggerNVCAnalysis();
            } else if (action == NVCErrorAction.saveText) {
              // 关闭详情页，记录已经保存
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: Scaffold(
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
            _formatDateTime(widget.record.createdAt),
            style: const TextStyle(
              color: Color(0xFF8B8B8B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
          actions: [
            // 分享按钮（使用 IconButton 保证在 AppBar 中始终可见）
            IconButton(
              onPressed: () => SharePosterScreen.show(
                context: context,
                record: widget.record,
              ),
              icon: const Icon(Icons.share_outlined,
                  size: 22, color: Color(0xFFC4A57B)),
              tooltip: '分享',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF5EBE0),
                foregroundColor: const Color(0xFFC4A57B),
              ),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  backgroundColor: const Color(0xFFC4A57B),
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
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 转写文本区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F0E8), // 米色背景
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.record.transcription,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 17,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 洞察标签
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: Color(0xFFC4A57B)),
                  const SizedBox(width: 6),
                  const Text(
                    '洞察',
                    style: TextStyle(
                      color: Color(0xFFC4A57B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 感受标签卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
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
                        const Expanded(
                          child: Text(
                            '我现在的感受',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                        ),
                        // 编辑按钮放在标题右侧
                        GestureDetector(
                          onTap: _editMoodTags,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // "也许..."提示 + 标签
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
                        Expanded(
                          child: _selectedMoods.isEmpty
                              ? Text(
                                  '点击编辑添加感受',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedMoods.map((mood) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE0D5C5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        mood,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF5D4E3C),
                                          fontWeight: FontWeight.w500,
                                        ),
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

              const SizedBox(height: 16),

              // NVC分析卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
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
                        const Text(
                          'NVC分析',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        Icon(
                          Icons.more_horiz,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // NVC分析按钮
                    GestureDetector(
                      onTap: _isAnalyzing ? null : _triggerNVCAnalysis,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isAnalyzing ? '正在分析中...' : '让AI来分析你的情况',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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
                                    Color(0xFFC4A57B),
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
                      color: Color(0xFF2C2C2C),
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
                    color: Colors.black.withOpacity(0.02),
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
                      backgroundColor: const Color(0xFFC4A57B),
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
