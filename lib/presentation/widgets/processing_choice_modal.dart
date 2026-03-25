import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/record.dart';
import '../../core/theme/app_typography.dart';

/// 处理选择的结果，包含模式和用户可能编辑过的转写文本
class ProcessingResult {
  final ProcessingMode mode;
  final String transcription;

  const ProcessingResult({required this.mode, required this.transcription});
}

class ProcessingChoiceModal extends StatefulWidget {
  final String transcription;
  final String? transcriptionErrorMessage;
  final Function(ProcessingResult) onSelect;
  final VoidCallback? onCancel;
  final VoidCallback? onNVCInsight;

  const ProcessingChoiceModal({
    super.key,
    required this.transcription,
    this.transcriptionErrorMessage,
    required this.onSelect,
    this.onCancel,
    this.onNVCInsight,
  });

  @override
  State<ProcessingChoiceModal> createState() => _ProcessingChoiceModalState();
}

class _ProcessingChoiceModalState extends State<ProcessingChoiceModal> {
  late TextEditingController _textController;
  // 标记用户是否手动编辑过文本
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    final isPlaceholder =
        widget.transcription.isEmpty || widget.transcription == '正在转写中...';
    _textController = TextEditingController(
      text: isPlaceholder ? '' : widget.transcription,
    );
  }

  @override
  void didUpdateWidget(ProcessingChoiceModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果用户还没有手动编辑，且外部传入了新的转写文本，则更新
    if (!_userEdited && widget.transcription != oldWidget.transcription) {
      final isPlaceholder =
          widget.transcription.isEmpty || widget.transcription == '正在转写中...';
      if (!isPlaceholder) {
        _textController.text = widget.transcription;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _selectMode(ProcessingMode mode) {
    final editedText = _textController.text.trim();
    final fallbackText = widget.transcription.trim();
    final hasFallbackText =
        fallbackText.isNotEmpty && fallbackText != '正在转写中...';
    if (editedText.isEmpty && !hasFallbackText) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.transcriptionErrorMessage ?? '请先输入内容'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.onSelect(ProcessingResult(
      mode: mode,
      transcription: editedText.isNotEmpty ? editedText : fallbackText,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasTranscriptionError =
        widget.transcriptionErrorMessage?.trim().isNotEmpty == true;
    final isPlaceholder = !hasTranscriptionError &&
        (widget.transcription.isEmpty || widget.transcription == '正在转写中...');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '录音完成',
                  style: AppTypography.modalTitle,
                ),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (hasTranscriptionError) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF1C1B7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Color(0xFFD86C54),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.transcriptionErrorMessage!,
                        style: AppTypography.modalCaption.copyWith(
                          color: const Color(0xFFB05A48),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 转写文本 - 可编辑
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
              child: isPlaceholder && !_userEdited
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFB8ADA0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '正在转写中...',
                            style: AppTypography.modalBody.copyWith(
                              color: const Color(0xFF9F8C7A),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      maxLines: null,
                      style: AppTypography.modalBody.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: hasTranscriptionError
                            ? '转写失败，请手动输入内容...'
                            : '点击编辑转写内容...',
                        hintStyle: AppTypography.modalBody,
                      ),
                      onChanged: (_) {
                        if (!_userEdited) {
                          setState(() => _userEdited = true);
                        }
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // 选项标题
            const Text(
              '选择处理方式',
              style: AppTypography.modalCaption,
            ),

            const SizedBox(height: 12),

            // 选项卡片（2列布局）
            Row(
              children: [
                // NVC 分析
                Expanded(
                  child: _ProcessingOption(
                    icon: Icons.lightbulb_outline,
                    title: 'NVC 分析',
                    description: '完整的情绪分析',
                    iconColor: AppColors.accent,
                    backgroundColor: const Color(0xFFFFF0E6),
                    onTap: widget.onNVCInsight ??
                        () {
                          _selectMode(ProcessingMode.withNVC);
                        },
                  ),
                ),

                const SizedBox(width: 12),

                // 仅记录文本
                Expanded(
                  child: _ProcessingOption(
                    icon: Icons.description_outlined,
                    title: '仅记录文本',
                    description: '不做进一步分析',
                    iconColor: const Color(0xFF9E9E9E),
                    backgroundColor: const Color(0xFFF2F2F2),
                    onTap: () {
                      _selectMode(ProcessingMode.onlyRecord);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ProcessingOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ProcessingOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              // 标题
              Text(
                title,
                style: AppTypography.modalButtonSecondary.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // 描述
              Text(
                description,
                style: AppTypography.modalCaption.copyWith(
                  color: const Color(0xFF9F8C7A),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
