import 'package:flutter/material.dart';
import '../../../domain/entities/nvc_analysis.dart';

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

  static Future<NVCAnalysis?> show({
    required BuildContext context,
    required NVCAnalysis initialAnalysis,
    required String transcription,
    VoidCallback? onRevert,
  }) {
    return showModalBottomSheet<NVCAnalysis>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NVCConfirmationModal(
        initialAnalysis: initialAnalysis,
        transcription: transcription,
        onConfirm: (analysis) => Navigator.of(context).pop(analysis),
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
    _observation = widget.initialAnalysis.observation;
    _feelings = List.from(widget.initialAnalysis.feelings);
    _needs = List.from(widget.initialAnalysis.needs);
    _insight = widget.initialAnalysis.insight ??
               widget.initialAnalysis.request ??
               '尝试在双方情绪平稳时，以"我"开头表达感受，而非指责。';
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

  void _editObservation() async {
    final result = await _showEditDialog('编辑事实观察', _observation);
    if (result != null) {
      setState(() => _observation = result);
    }
  }

  void _editInsight() async {
    final result = await _showEditDialog('编辑行动 Tips', _insight);
    if (result != null) {
      setState(() => _insight = result);
    }
  }

  Future<String?> _showEditDialog(String title, String initialValue) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
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
                  onPressed: _handleConfirm,
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                    onEdit: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('编辑感受功能暂未开放')),
                      );
                    },
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
                    onEdit: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('编辑需要功能暂未开放')),
                      );
                    },
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
          // 标题行
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
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

          const SizedBox(height: 12),

          // 确认按钮和编辑图标
          Row(
            children: [
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Center(
                  child: Text(
                    '确认',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}
