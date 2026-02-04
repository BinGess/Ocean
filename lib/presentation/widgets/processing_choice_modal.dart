import 'package:flutter/material.dart';
import '../../domain/entities/record.dart';

/// 处理选择的结果，包含模式和用户可能编辑过的转写文本
class ProcessingResult {
  final ProcessingMode mode;
  final String transcription;

  const ProcessingResult({required this.mode, required this.transcription});
}

class ProcessingChoiceModal extends StatefulWidget {
  final String transcription;
  final Function(ProcessingResult) onSelect;
  final VoidCallback? onCancel;
  final VoidCallback? onNVCInsight;

  const ProcessingChoiceModal({
    super.key,
    required this.transcription,
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
    final isPlaceholder = widget.transcription.isEmpty ||
        widget.transcription == '正在转写中...';
    _textController = TextEditingController(
      text: isPlaceholder ? '' : widget.transcription,
    );
  }

  @override
  void didUpdateWidget(ProcessingChoiceModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果用户还没有手动编辑，且外部传入了新的转写文本，则更新
    if (!_userEdited && widget.transcription != oldWidget.transcription) {
      final isPlaceholder = widget.transcription.isEmpty ||
          widget.transcription == '正在转写中...';
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
    widget.onSelect(ProcessingResult(
      mode: mode,
      transcription: editedText.isNotEmpty ? editedText : widget.transcription,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = widget.transcription.isEmpty ||
        widget.transcription == '正在转写中...';

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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
              GestureDetector(
                onTap: widget.onCancel,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    size: 24,
                    color: Color(0xFF8B7D6B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 转写文本 - 可编辑
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE8DED0),
                width: 1,
              ),
            ),
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
            child: isPlaceholder && !_userEdited
                ? const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFB8ADA0),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '正在转写中...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFFB8ADA0),
                          ),
                        ),
                      ],
                    ),
                  )
                : TextField(
                    controller: _textController,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF5D4E3C),
                      height: 1.5,
                    ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: '点击编辑转写内容...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: Color(0xFFB8ADA0),
                    ),
                    ),
                    onChanged: (_) {
                      if (!_userEdited) {
                        setState(() => _userEdited = true);
                      }
                    },
                  ),
          ),

          const SizedBox(height: 28),

          // 选项标题
          const Text(
            '选择处理方式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),

          const SizedBox(height: 16),

          // 选项卡片（2列布局）
          Row(
            children: [
              // NVC 分析
              Expanded(
                child: _ProcessingOption(
                  icon: Icons.lightbulb_outline,
                  title: 'NVC 分析',
                  description: '完整的情绪分析',
                  iconColor: const Color(0xFFB794F6), // 紫色
                  backgroundColor: const Color(0xFFF3EBFF),
                  onTap: widget.onNVCInsight ?? () {
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
                  iconColor: const Color(0xFF7DBEF5), // 蓝色
                  backgroundColor: const Color(0xFFE8F4FD),
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

  static Future<ProcessingResult?> show({
    required BuildContext context,
    required String transcription,
  }) {
    return showModalBottomSheet<ProcessingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProcessingChoiceModal(
        transcription: transcription,
        onSelect: (result) => Navigator.of(context).pop(result),
        onCancel: () => Navigator.of(context).pop(),
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
            color: const Color(0xFFFAF8F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8DED0),
              width: 1,
            ),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // 描述
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB8ADA0),
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
