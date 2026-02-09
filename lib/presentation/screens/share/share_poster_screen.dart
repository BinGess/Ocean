/// 分享海报预览页面
/// 支持三种风格切换和分享功能
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../../../domain/entities/record.dart';
import '../../widgets/share_poster/share_poster.dart';

class SharePosterScreen extends StatefulWidget {
  final Record record;

  const SharePosterScreen({
    super.key,
    required this.record,
  });

  /// 静态方法：打开分享海报页面
  static Future<void> show({
    required BuildContext context,
    required Record record,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SharePosterScreen(record: record),
      ),
    );
  }

  @override
  State<SharePosterScreen> createState() => _SharePosterScreenState();
}

class _SharePosterScreenState extends State<SharePosterScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  PosterStyle _currentStyle = PosterStyle.auraGradient;
  bool _isDarkMode = false;
  bool _isSharing = false;

  late PosterData _posterData;

  @override
  void initState() {
    super.initState();
    _posterData = PosterData.fromRecord(widget.record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _isDarkMode ? Colors.white70 : const Color(0xFF2C2C2C),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '分享海报',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF2C2C2C),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // 暗黑模式切换
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: _isDarkMode ? Colors.white70 : const Color(0xFF6B7280),
            ),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 海报预览区域
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Screenshot(
                  controller: _screenshotController,
                  child: _buildPoster(),
                ),
              ),
            ),
          ),

          // 底部控制区域
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildPoster() {
    switch (_currentStyle) {
      case PosterStyle.soulReceipt:
        return SoulReceiptPoster(
          data: _posterData,
          isDarkMode: _isDarkMode,
        );
      case PosterStyle.auraGradient:
        return AuraGradientPoster(
          data: _posterData,
          isDarkMode: _isDarkMode,
        );
      case PosterStyle.editorial:
        return EditorialPoster(
          data: _posterData,
          isDarkMode: _isDarkMode,
        );
    }
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 风格选择器
            _buildStyleSelector(),

            const SizedBox(height: 20),

            // 操作按钮
            Row(
              children: [
                // 保存到相册
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.save_alt,
                    label: '保存图片',
                    onTap: _saveToGallery,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 12),
                // 分享
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    icon: Icons.share,
                    label: '分享',
                    onTap: _shareImage,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStyleOption(
          style: PosterStyle.soulReceipt,
          label: '票据',
          icon: Icons.receipt_long,
        ),
        const SizedBox(width: 16),
        _buildStyleOption(
          style: PosterStyle.auraGradient,
          label: '光晕',
          icon: Icons.blur_on,
        ),
        const SizedBox(width: 16),
        _buildStyleOption(
          style: PosterStyle.editorial,
          label: '杂志',
          icon: Icons.article,
        ),
      ],
    );
  }

  Widget _buildStyleOption({
    required PosterStyle style,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentStyle == style;
    final primaryColor = _isDarkMode ? Colors.white : const Color(0xFF48697A);
    final secondaryColor = _isDarkMode ? Colors.white38 : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentStyle = style;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDarkMode ? Colors.white12 : const Color(0xFFE6EEF2))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? primaryColor : secondaryColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? primaryColor : secondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final primaryColor = const Color(0xFF48697A);

    return GestureDetector(
      onTap: _isSharing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? primaryColor : (_isDarkMode ? Colors.white12 : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSharing && isPrimary)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPrimary ? Colors.white : primaryColor,
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : (_isDarkMode ? Colors.white70 : primaryColor),
              ),
            const SizedBox(width: 8),
            Text(
              _isSharing && isPrimary ? '处理中...' : label,
              style: TextStyle(
                fontSize: 15,
                color: isPrimary ? Colors.white : (_isDarkMode ? Colors.white70 : primaryColor),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (imageBytes == null) {
        _showError('生成图片失败');
        return;
      }

      // 保存到临时目录
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '瞬记_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // 使用系统分享保存到相册
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '保存到相册',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('图片已准备好'),
              ],
            ),
            backgroundColor: Color(0xFF5D4E3C),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _shareImage() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (imageBytes == null) {
        _showError('生成图片失败');
        return;
      }

      // 保存到临时目录
      final directory = await getTemporaryDirectory();
      final fileName = '瞬记_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // 分享
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '瞬记 - 看见情绪的纹理',
      );
    } catch (e) {
      _showError('分享失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
