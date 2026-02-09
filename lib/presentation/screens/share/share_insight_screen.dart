/// 分享洞察海报页面
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../../../domain/entities/insight_report.dart';
import '../../widgets/share_poster/insight_poster.dart';

class ShareInsightScreen extends StatefulWidget {
  final InsightReport report;

  const ShareInsightScreen({
    super.key,
    required this.report,
  });

  /// 静态方法：打开分享洞察页面
  static Future<void> show({
    required BuildContext context,
    required InsightReport report,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareInsightScreen(report: report),
      ),
    );
  }

  @override
  State<ShareInsightScreen> createState() => _ShareInsightScreenState();
}

class _ShareInsightScreenState extends State<ShareInsightScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDarkMode = false;
  bool _isSharing = false;

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
          '分享洞察',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF2C2C2C),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
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
                  child: InsightPoster(
                    report: widget.report,
                    isDarkMode: _isDarkMode,
                  ),
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
        child: Row(
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    const primaryColor = Color(0xFF48697A);

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
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '瞬记洞察_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

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

      final directory = await getTemporaryDirectory();
      final fileName = '瞬记洞察_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '瞬记周洞察 - 看见情绪的纹理',
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
