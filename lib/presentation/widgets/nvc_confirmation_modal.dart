import 'package:flutter/material.dart';
import '../../../domain/entities/nvc_analysis.dart';
import 'delete_confirmation_dialog.dart';

class NVCConfirmationModal extends StatefulWidget {
  final NVCAnalysis initialAnalysis;
  final String transcription;
  final Function(NVCAnalysis) onConfirm;
  final VoidCallback? onRevert;

  const NVCConfirmationModal({
    super.key,
    required this.initialAnalysis,
    required this.transcription,
    required this.onConfirm,
    this.onRevert,
  });

  @override
  State<NVCConfirmationModal> createState() => _NVCConfirmationModalState();

  static Future<NVCModalResult?> show({
    required BuildContext context,
    required NVCAnalysis initialAnalysis,
    required String transcription,
    VoidCallback? onRevert,
  }) {
    return showModalBottomSheet<NVCModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NVCConfirmationModal(
        initialAnalysis: initialAnalysis,
        transcription: transcription,
        onConfirm: (analysis) => Navigator.of(context).pop(
          NVCModalResult(action: NVCModalAction.confirm, analysis: analysis),
        ),
        onRevert: onRevert,
      ),
    );
  }
}

class _NVCConfirmationModalState extends State<NVCConfirmationModal> {
  late String _observation;
  late List<Feeling> _feelings;
  late List<Need> _needs;
  late String _insight;

  @override
  void initState() {
    super.initState();
    _observation = _stripSquareBrackets(widget.initialAnalysis.observation);
    _feelings = List.from(widget.initialAnalysis.feelings);
    _needs = List.from(widget.initialAnalysis.needs);
    _insight = widget.initialAnalysis.insight ??
               widget.initialAnalysis.request ??
               '尝试在双方情绪平稳时，以"我"开头表达感受，而非指责。';
  }

  String _stripSquareBrackets(String value) {
    var text = value.trim();
    if (text.startsWith('[') && text.endsWith(']') && text.length >= 2) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  void _handleConfirm() {
    final updatedAnalysis = widget.initialAnalysis.copyWith(
      observation: _observation,
      feelings: _feelings,
      needs: _needs,
      insight: _insight,
      analyzedAt: DateTime.now(),
    );
    widget.onConfirm(updatedAnalysis);
  }

  void _handleDelete() async {
    // 显示删除确认对话框
    final confirmed = await DeleteConfirmationDialog.show(context: context);
    if (confirmed == true) {
      Navigator.of(context).pop(
        NVCModalResult(action: NVCModalAction.delete),
      ); // 关闭NVC弹窗，返回删除动作
    }
  }

  void _editObservation() async {
    final result = await _showEditDialog(
      title: '编辑事实观察',
      initialValue: _observation,
      iconColor: const Color(0xFF007AFF),
      iconBgColor: const Color(0xFFE8F4FD),
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
      iconColor: const Color(0xFFAF52DE),
      iconBgColor: const Color(0xFFF3EBFF),
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
        _feelings = result.map((tag) => Feeling(
          feeling: tag,
          intensity: IntensityLevel.medium,
        )).toList();
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
        // 用顿号或逗号分隔
        final needsList = result.split(RegExp(r'[、,，]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        _needs = needsList.map((need) => Need(
          need: need,
          reason: '',
        )).toList();
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
                        color: Color(0xFF2C2C2C),
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
                        backgroundColor: const Color(0xFF007AFF),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 格式化日期时间
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日·${now.hour < 12 ? "上午" : "下午"}${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      height: size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5), // 糯米色背景
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: _handleDelete,
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 转写文本区域
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6), // 浅黄色背景
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

                  // 洞察标签
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        '洞察',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 1. 事实观察（带蓝色边框）
                  _buildNVCCard(
                    context: context,
                    icon: Icons.remove_red_eye_outlined,
                    iconColor: const Color(0xFF007AFF),
                    iconBgColor: const Color(0xFFE8F4FD),
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
                    highlighted: true,
                  ),

                  const SizedBox(height: 12),

                  // 2. 我现在的感受
                  _buildNVCCard(
                    context: context,
                    icon: Icons.favorite,
                    iconColor: const Color(0xFFFF9500),
                    iconBgColor: const Color(0xFFFFF4E6),
                    title: '我现在的感受',
                    content: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _feelings.map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E6), // 浅黄色
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          f.feeling,
                          style: const TextStyle(
                            color: Color(0xFFCC7A00),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                    onEdit: _editFeelings,
                  ),

                  const SizedBox(height: 12),

                  // 3. 我需要
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

                  // 4. 行动Tips
                  _buildNVCCard(
                    context: context,
                    icon: Icons.lightbulb_outline,
                    iconColor: const Color(0xFFAF52DE),
                    iconBgColor: const Color(0xFFF3EBFF),
                    title: '行动Tips',
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // 底部完成按钮
          Container(
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
                  onPressed: _handleConfirm,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF5A9FD4),
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
        ],
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
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: highlighted
            ? Border.all(color: const Color(0xFF007AFF), width: 2)
            : null,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                    color: Color(0xFF2C2C2C),
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

          // 也许提示 + 内容
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? widget.iconBgColor : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? widget.iconColor : const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? widget.iconColor : const Color(0xFF4A4A4A),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      backgroundColor: const Color(0xFF007AFF),
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
  delete,  // 删除记录
}

/// NVC弹窗返回结果
class NVCModalResult {
  final NVCModalAction action;
  final NVCAnalysis? analysis;

  NVCModalResult({
    required this.action,
    this.analysis,
  });
}
