/// API 测试调试页面
/// 用于测试豆包 API 连接和配置

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/doubao_llm_client.dart';
import '../../../core/network/doubao_asr_client.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final List<String> _logs = [];
  bool _isTestingLLM = false;
  bool _isTestingASR = false;

  @override
  void initState() {
    super.initState();
    _addLog('📱 API 测试页面已加载');
    _checkConfiguration();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    debugPrint(message);
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  /// 检查配置状态
  void _checkConfiguration() {
    _addLog('🔍 检查环境变量配置...');

    final config = EnvConfig.getConfigStatus();
    config.forEach((key, value) {
      _addLog('  $key: $value');
    });

    if (EnvConfig.isConfigured) {
      _addLog('✅ 环境变量配置完整');
    } else {
      _addLog('❌ 环境变量配置不完整，请检查 .env 文件');
    }
  }

  /// 测试 LLM API
  Future<void> _testLLMAPI() async {
    if (_isTestingLLM) return;

    setState(() {
      _isTestingLLM = true;
    });

    try {
      _addLog('');
      _addLog('🧪 开始测试 LLM API...');

      if (EnvConfig.doubaoLlmApiKey.isEmpty) {
        _addLog('❌ LLM API Key 未配置');
        return;
      }

      _addLog('📡 创建 LLM 客户端...');
      final client = DoubaoLLMClient(
        apiKey: EnvConfig.doubaoLlmApiKey,
        endpoint: AppConstants.doubaoLlmEndpoint,
      );

      _addLog('📤 发送测试请求...');
      _addLog('   提示词: "你好，请简单介绍一下 NVC（非暴力沟通）框架"');

      final response = await client.analyzeWithNVC(
        transcription: '今天开会时，老板当众批评了我的方案，我感到很委屈和愤怒。',
      );

      if (response.success) {
        _addLog('✅ LLM API 响应成功');
        _addLog('📝 响应内容:');
        _addLog(response.content ?? '(空)');
      } else {
        _addLog('❌ LLM API 请求失败');
        _addLog('   错误: ${response.error}');
      }

      client.dispose();
    } catch (e, stackTrace) {
      _addLog('❌ 测试失败: $e');
      _addLog('   堆栈: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    } finally {
      setState(() {
        _isTestingLLM = false;
      });
    }
  }

  /// 测试 ASR WebSocket
  Future<void> _testASRWebSocket() async {
    if (_isTestingASR) return;

    setState(() {
      _isTestingASR = true;
    });

    try {
      _addLog('');
      _addLog('🧪 开始测试 ASR WebSocket...');

      if (EnvConfig.doubaoAsrAppKey.isEmpty ||
          EnvConfig.doubaoAsrAccessKey.isEmpty) {
        _addLog('❌ ASR 配置不完整');
        return;
      }

      _addLog('📡 创建 ASR 客户端...');
      final client = DoubaoASRClient();

      // 监听响应
      client.responses.listen(
        (response) {
          if (response.success) {
            _addLog('✅ ASR 响应: ${response.text ?? "(无文本)"}');
            if (response.isFinal) {
              _addLog('🏁 最终识别结果');
            }
          } else {
            _addLog('❌ ASR 错误: ${response.error}');
          }
        },
        onError: (error) {
          _addLog('❌ 流错误: $error');
        },
      );

      _addLog('🔌 连接 WebSocket...');
      _addLog('   Endpoint: ${AppConstants.doubaoAsrEndpoint}');

      await client.connect(
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );

      _addLog('✅ WebSocket 已连接');

      // 发送测试音频数据（模拟）
      _addLog('📤 发送测试音频包...');

      // 创建模拟的音频数据（静音）
      final testAudio = Uint8List(3200); // 200ms @ 16kHz
      await client.sendAudio(testAudio);

      _addLog('✅ 音频包已发送');

      // 等待 2 秒后结束
      await Future.delayed(const Duration(seconds: 2));

      _addLog('📤 发送结束标记...');
      await client.finishAudio();

      _addLog('⏱️ 等待响应...');
      await Future.delayed(const Duration(seconds: 3));

      _addLog('🔌 断开连接...');
      await client.disconnect();

      _addLog('✅ ASR 测试完成');

      client.dispose();
    } catch (e, stackTrace) {
      _addLog('❌ 测试失败: $e');
      _addLog('   堆栈: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    } finally {
      setState(() {
        _isTestingASR = false;
      });
    }
  }

  /// 复制日志到剪贴板
  void _copyLogs() {
    final logsText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 测试调试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: '复制日志',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: '清空日志',
          ),
        ],
      ),
      body: Column(
        children: [
          // 配置状态卡片
          _buildConfigCard(),

          // 测试按钮
          _buildTestButtons(),

          const Divider(height: 1),

          // 日志显示区域
          Expanded(
            child: _buildLogsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    final isConfigured = EnvConfig.isConfigured;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfigured ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfigured ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConfigured ? Icons.check_circle : Icons.warning,
                color: isConfigured ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                isConfigured ? '配置完整' : '配置不完整',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildConfigItem('ASR App Key', EnvConfig.doubaoAsrAppKey),
          _buildConfigItem('ASR Access Key', EnvConfig.doubaoAsrAccessKey),
          _buildConfigItem('ASR Resource ID', EnvConfig.doubaoAsrResourceId),
          _buildConfigItem('LLM API Key', EnvConfig.doubaoLlmApiKey),
          _buildConfigItem('Model ID', EnvConfig.doubaoModelId),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    final isConfigured = value.isNotEmpty;
    final displayValue = isConfigured
        ? (value.length > 20 ? '${value.substring(0, 20)}...' : value)
        : '未配置';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isConfigured ? Icons.check : Icons.close,
            size: 16,
            color: isConfigured ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $displayValue',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isTestingLLM ? null : _testLLMAPI,
              icon: _isTestingLLM
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology),
              label: const Text('测试 LLM API'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isTestingASR ? null : _testASRWebSocket,
              icon: _isTestingASR
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic),
              label: const Text('测试 ASR WebSocket'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          '暂无日志\n点击上方按钮开始测试',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        Color? textColor;

        if (log.contains('✅')) {
          textColor = Colors.green.shade700;
        } else if (log.contains('❌')) {
          textColor = Colors.red.shade700;
        } else if (log.contains('⚠️')) {
          textColor = Colors.orange.shade700;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: textColor,
            ),
          ),
        );
      },
    );
  }
}
