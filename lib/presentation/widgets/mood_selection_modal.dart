
import 'package:flutter/material.dart';

class MoodSelectionModal extends StatefulWidget {
  final List<String> initialSelectedMoods;
  final Function(List<String>) onConfirm;

  const MoodSelectionModal({
    super.key,
    this.initialSelectedMoods = const [],
    required this.onConfirm,
  });

  @override
  State<MoodSelectionModal> createState() => _MoodSelectionModalState();

  static Future<List<String>?> show({
    required BuildContext context,
    List<String> initialSelectedMoods = const [],
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoodSelectionModal(
        initialSelectedMoods: initialSelectedMoods,
        onConfirm: (moods) => Navigator.of(context).pop(moods),
      ),
    );
  }
}

class _MoodSelectionModalState extends State<MoodSelectionModal> {
  late List<String> _selectedMoods;

  // 预定义情绪列表
  final List<String> _moods = [
    '开心', '兴奋', '感激', '平静', '放松',
    '焦虑', '担心', '害怕', '紧张', '压力',
    '生气', '愤怒', '烦躁', '委屈', '挫败',
    '悲伤', '失望', '孤独', '疲惫', '无聊',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMoods = List.from(widget.initialSelectedMoods);
  }

  void _toggleMood(String mood) {
    setState(() {
      if (_selectedMoods.contains(mood)) {
        _selectedMoods.remove(mood);
      } else {
        if (_selectedMoods.length < 3) {
          _selectedMoods.add(mood);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多选择3个情绪')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('选择情绪', style: theme.textTheme.titleLarge),
              TextButton(
                onPressed: () => widget.onConfirm(_selectedMoods),
                child: const Text('确定'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '你现在的感受是什么？(最多选3个)',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moods.map((mood) {
                  final isSelected = _selectedMoods.contains(mood);
                  return FilterChip(
                    label: Text(mood),
                    selected: isSelected,
                    onSelected: (_) => _toggleMood(mood),
                    selectedColor: theme.primaryColor.withOpacity(0.2),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
