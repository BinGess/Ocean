import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection.dart';
import '../../../domain/repositories/insight_repository.dart';
import '../../../domain/repositories/record_repository.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exportingRecords = false;
  bool _exportingInsights = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '导出',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExportItem(
            title: '导出所有记录',
            subtitle: '包含语音转写、情绪、NVC 等字段',
            icon: Icons.description_outlined,
            isLoading: _exportingRecords,
            onTap: _exportingRecords ? null : _exportAllRecords,
          ),
          const SizedBox(height: 12),
          _buildExportItem(
            title: '导出洞察信息',
            subtitle: '包含每周洞察报告（缓存）',
            icon: Icons.auto_awesome_outlined,
            isLoading: _exportingInsights,
            onTap: _exportingInsights ? null : _exportInsights,
          ),
        ],
      ),
    );
  }

  Widget _buildExportItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF8B7D6B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllRecords() async {
    setState(() => _exportingRecords = true);
    try {
      final repository = getIt<RecordRepository>();
      final records = await repository.getAllRecords();
      if (records.isEmpty) {
        _showToast('没有可导出的记录');
        return;
      }

      final payload = {
        'exported_at': DateTime.now().toIso8601String(),
        'count': records.length,
        'records': records.map((record) => record.toJson()).toList(),
      };
      final file = await _writeJsonFile(prefix: 'records_export', payload: payload);
      final shared = await _tryShareFile(context, file, text: '瞬记-记录导出');
      _showToast(shared
          ? '已导出 ${records.length} 条记录'
          : '已保存到本地：${file.path}');
    } catch (e) {
      debugPrint('Export records failed: $e');
      _showToast('导出失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() => _exportingRecords = false);
      }
    }
  }

  Future<void> _exportInsights() async {
    setState(() => _exportingInsights = true);
    try {
      final repository = getIt<InsightRepository>();
      final caches = await repository.getAllCachedInsightReports();
      if (caches.isEmpty) {
        _showToast('没有可导出的洞察报告');
        return;
      }

      final payload = {
        'exported_at': DateTime.now().toIso8601String(),
        'count': caches.length,
        'reports': caches
            .map((cache) => {
                  'cached_at': cache.cachedAt.toIso8601String(),
                  'report': cache.report.toJson(),
                })
            .toList(),
      };
      final file = await _writeJsonFile(prefix: 'insights_export', payload: payload);
      final shared = await _tryShareFile(context, file, text: '瞬记-洞察导出');
      _showToast(shared
          ? '已导出 ${caches.length} 份洞察报告'
          : '已保存到本地：${file.path}');
    } catch (e) {
      debugPrint('Export insights failed: $e');
      _showToast('导出失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() => _exportingInsights = false);
      }
    }
  }

  Future<bool> _tryShareFile(BuildContext context, File file, {String? text}) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        sharePositionOrigin: origin,
      );
      return true;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }

  Future<File> _writeJsonFile({
    required String prefix,
    required Map<String, dynamic> payload,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final file = File('${directory.path}/${prefix}_$timestamp.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
    return file;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
