/// 记录详情页面
/// 用于查看和编辑单条记录，支持添加标签和触发NVC分析

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_event.dart';
import '../../bloc/record/record_state.dart';
import '../../widgets/nvc_confirmation_modal.dart';

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
    _selectedMoods = widget.record.moods != null
        ? List<String>.from(widget.record.moods!)
        : [];
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
        suggestions: ['焦虑', '开心', '平静', '愤怒', '悲伤', '好奇', '思考', '感激', '疲惫', '兴奋', '不适', '愧疚', '无奈'],
        iconColor: const Color(0xFFFF9500),
        iconBgColor: const Color(0xFFFFF4E6),
        icon: Icons.favorite,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMoods = result;
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listener: (context, state) {
        if (state.status == RecordStatus.analyzed && _isAnalyzing) {
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
            ).then((confirmedAnalysis) {
              if (confirmedAnalysis != null) {
                // TODO: 保存NVC分析结果到记录
                Navigator.of(context).pop(); // 关闭详情页
              }
            });
          }
        } else if (state.status == RecordStatus.error && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'NVC分析失败'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
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
            TextButton(
              onPressed: _saveAndClose,
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
                  color: const Color(0xFFFFF9E6), // 浅黄色背景
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.record.transcription,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
                              fontSize: 15,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF4E6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        mood,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFCC7A00),
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
