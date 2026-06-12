import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/coze_ai_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/deep_analysis_result.dart';
import '../../../domain/entities/nvc_analysis.dart';

enum DeeperSupportType {
  cognitiveReframe,
  releaseControl,
  selfCompassion,
  boundarySupport,
  gentleRecovery,
}

typedef DeepAnalysisLoader = Future<DeepAnalysisResult> Function(
  String methodType,
  String transcription,
);

// ---------- 关键词表（路由与占位内容共用） ----------

/// 低谷面：自我攻击 / 自责 / 羞耻
const _selfAttackKeywords = [
  '是不是我',
  '不行',
  '没用',
  '能力',
  '差劲',
  '自责',
  '内疚',
  '我怎么',
  '不够',
  '忘记',
  '失败',
  '做不好',
  '对不起',
  '亏欠',
];

/// 人际边界 / 高强度情绪（DBT）
const _boundaryKeywords = [
  '同事',
  '家属',
  '妈妈',
  '爸爸',
  '老公',
  '老婆',
  '沟通',
  '解释',
  '边界',
  '吵',
  '打断',
  '说话',
  '被冒犯',
  '尴尬',
  '凭什么',
  '憋屈',
];

/// 耗竭 / 奖赏掉线（BA）
const _recoveryKeywords = [
  '累',
  '疲惫',
  '耳鸣',
  '涣散',
  '吃饭',
  '生存',
  '快乐少',
  '麻木',
  '睡觉',
  '没劲',
  '身体',
  '散步',
  '提不起',
  '恢复',
  '心累',
  '没力气',
];

/// 反刍 / 纠缠 / 意义过载（ACT）
const _releaseKeywords = [
  '睡不着',
  '想不通',
  '反复',
  '一直想',
  '停不下来',
  '控制',
  '意义',
  '纠结',
  '脑子',
  '思绪',
  '放不下',
];

/// 高光面：积极体验 / 值得品味放大的好
const _savoringKeywords = [
  '开心',
  '幸福',
  '真好',
  '太好',
  '美好',
  '很美',
  '了不起',
  '厉害',
  '成就',
  '赚到',
  '里程碑',
  '感恩',
  '感激',
  '被暖',
  '可爱',
  '兴奋',
  '骄傲',
  '满足',
  '顺利',
  '舒服',
];

class DeeperSupportRecommendation {
  final DeeperSupportType type;
  final String title;
  final String methodLabel;
  final String theorySource;
  final String shortDescription;
  final String stuckPoint;
  final String groundedUnderstanding;
  final String oneSmallStep;
  final String steadySentence;

  // ---- 自我关怀与滋养（新结构）扩展，其余方法为 null ----
  final String? face;
  final bool enoughSignal;
  final String? resonance;
  final List<DeepEmotion> emotions;
  final String? observedLabel;
  final String? observedValue;
  final String? truthLabel;
  final String? truthValue;
  final String? microActionKind;

  const DeeperSupportRecommendation({
    required this.type,
    required this.title,
    required this.methodLabel,
    required this.theorySource,
    required this.shortDescription,
    required this.stuckPoint,
    required this.groundedUnderstanding,
    required this.oneSmallStep,
    required this.steadySentence,
    this.face,
    this.enoughSignal = true,
    this.resonance,
    this.emotions = const [],
    this.observedLabel,
    this.observedValue,
    this.truthLabel,
    this.truthValue,
    this.microActionKind,
  });

  DeepAnalysisResult toResult() {
    return DeepAnalysisResult(
      type: type.name,
      title: title,
      methodLabel: methodLabel,
      theorySource: theorySource,
      overview: shortDescription,
      stuckPoint: stuckPoint,
      groundedUnderstanding: groundedUnderstanding,
      oneSmallStep: oneSmallStep,
      steadySentence: steadySentence,
      analyzedAt: DateTime.now(),
      face: face,
      enoughSignal: enoughSignal,
      resonance: resonance,
      emotions: emotions,
      observedLabel: observedLabel,
      observedValue: observedValue,
      truthLabel: truthLabel,
      truthValue: truthValue,
      microActionKind: microActionKind,
    );
  }
}

DeeperSupportType recommendedDeeperSupportType({
  required String transcription,
  required NVCAnalysis analysis,
}) {
  // 优先采用 NVC 智能体直接给出的分诊结果（新字段，向后兼容）；
  // 字段缺失或值非法时，回退到本地关键词路由。
  final agentRecommended = analysis.recommendedMethod?.trim();
  if (agentRecommended != null && agentRecommended.isNotEmpty) {
    for (final type in DeeperSupportType.values) {
      if (type.name == agentRecommended) {
        return type;
      }
    }
  }

  final text = [
    transcription,
    analysis.observation,
    analysis.request ?? '',
    analysis.insight ?? '',
    analysis.feelings.map((item) => item.feeling).join(' '),
    analysis.needs.map((item) => item.need).join(' '),
  ].join(' ').toLowerCase();

  if (_containsAny(text, _selfAttackKeywords)) {
    return DeeperSupportType.selfCompassion;
  }

  if (_containsAny(text, _boundaryKeywords)) {
    return DeeperSupportType.boundarySupport;
  }

  if (_containsAny(text, _recoveryKeywords)) {
    return DeeperSupportType.gentleRecovery;
  }

  if (_containsAny(text, _releaseKeywords)) {
    return DeeperSupportType.releaseControl;
  }

  // 高光面：积极体验交给「自我关怀与滋养」品味放大，而不是落进想法校准
  if (_containsAny(text, _savoringKeywords)) {
    return DeeperSupportType.selfCompassion;
  }

  return DeeperSupportType.cognitiveReframe;
}

List<DeeperSupportRecommendation> buildDeeperSupportRecommendations({
  required String transcription,
  required NVCAnalysis analysis,
}) {
  return DeeperSupportType.values
      .map(
        (type) => _buildRecommendation(
          type: type,
          transcription: transcription,
          analysis: analysis,
        ),
      )
      .toList();
}

DeeperSupportRecommendation _buildRecommendation({
  required DeeperSupportType type,
  required String transcription,
  required NVCAnalysis analysis,
}) {
  switch (type) {
    case DeeperSupportType.cognitiveReframe:
      return const DeeperSupportRecommendation(
        type: DeeperSupportType.cognitiveReframe,
        title: '想法校准',
        methodLabel: 'CBT',
        theorySource: '源自经典认知行为学派',
        shortDescription: '帮助你把事实与脑中迅速出现的判断分开，减少被“我不行”这样的结论拖走。',
        stuckPoint: '这次让你更辛苦的，也许不只是事情难，而是你已经开始把不确定、超负荷和延迟，解释成“是不是我有问题”。',
        groundedUnderstanding: '压力过大和结果未定，都会让人自动往最坏处想。这说明你的系统在拉警报，不等于那个判断就是真的。',
        oneSmallStep: '把你脑子里最吓人的那个结论写下来，再补一句证据：有哪些事实能证明它？又有哪些事实并不能支持它？',
        steadySentence: '我现在感到慌，不代表我看到的结论就已经成立。',
      );
    case DeeperSupportType.releaseControl:
      return const DeeperSupportRecommendation(
        type: DeeperSupportType.releaseControl,
        title: '放下控制',
        methodLabel: 'ACT',
        theorySource: '源自第三波认知行为疗法',
        shortDescription: '帮助你不再急着解决每一个念头，在无法确定时也能先回到当下。',
        stuckPoint: '你现在最累的，可能不是这些问题本身，而是你很想快点把它们想明白、想完整、想出一个确定答案。',
        groundedUnderstanding: '有时候真正困住人的，不是念头出现了，而是我们太努力地想把它们立刻处理掉。越抓紧，越难停下来。',
        oneSmallStep: '先不继续推演结局，只做一个把注意力带回当下的小动作：数三次呼吸，感受脚底、椅子或床的支撑。',
        steadySentence: '我不需要现在就想通一切，才能让自己先缓下来。',
      );
    case DeeperSupportType.selfCompassion:
      return _buildSelfCompassionRecommendation(
        transcription: transcription,
        analysis: analysis,
      );
    case DeeperSupportType.boundarySupport:
      return const DeeperSupportRecommendation(
        type: DeeperSupportType.boundarySupport,
        title: '稳住情绪',
        methodLabel: 'DBT',
        theorySource: '源自第三波认知行为疗法',
        shortDescription: '帮助你先降低情绪强度，再用清楚、稳定的方式表达边界。',
        stuckPoint: '这次让你难受的，可能不只是事情本身，而是你一边在忍，一边又很想立刻让对方明白你的不舒服。',
        groundedUnderstanding: '你不是反应太大，而是你已经感到被挤压了。先稳住自己，才更有机会把真正想说的话说清楚。',
        oneSmallStep: '先准备一句短而稳的话，只描述此刻的需要，不解释前因后果。比如：“我们先慢一点说，我有点跟不上。”',
        steadySentence: '我不需要先爆发，才能证明我的感受是真的。',
      );
    case DeeperSupportType.gentleRecovery:
      return const DeeperSupportRecommendation(
        type: DeeperSupportType.gentleRecovery,
        title: '慢慢带回自己',
        methodLabel: 'Behavioral Activation',
        theorySource: '源自行为主义与 CBT 干预传统',
        shortDescription: '帮助你从微小行动重新接回节律、感受和生活里的恢复感。',
        stuckPoint: '你现在可能不是没想明白，而是整个人已经太满、太累，感受能力和恢复能力都被压住了。',
        groundedUnderstanding:
            '当生活只剩功能、没有滋养时，人会越来越像在硬撑。你需要的不是再逼自己一把，而是重新接回一点身体和生活感。',
        oneSmallStep: '今晚只做一件能让身体知道“我被照顾了”的小事：好好吃一顿饭、洗个热水澡，或者离开屏幕安静坐十分钟。',
        steadySentence: '我可以先把自己慢慢带回来，再去面对那些还没解决的事。',
      );
  }
}

/// 自我关怀与滋养：同一条轴的两端——低谷时站回自己这边，高光时接住自己的好。
/// 此处为本地占位拆解（智能体接入后由模型结果替换，结构一致）。
DeeperSupportRecommendation _buildSelfCompassionRecommendation({
  required String transcription,
  required NVCAnalysis analysis,
}) {
  final text = transcription.trim();
  final lower = text.toLowerCase();
  final hasLow = _containsAny(lower, _selfAttackKeywords);
  final hasHigh = _containsAny(lower, _savoringKeywords);
  // 两端都有时，先照顾痛的那一面
  final isHigh = hasHigh && !hasLow;
  final enoughSignal = text.replaceAll(RegExp(r'\s'), '').length >= 6;

  final emotions = analysis.feelings
      .take(4)
      .map(
        (item) => DeepEmotion(
          name: item.feeling,
          intensity: _intensityScore(item.intensity),
        ),
      )
      .toList();

  if (isHigh) {
    final observed = _extractSentence(text, _savoringKeywords) ?? '今天遇到的那件好事';
    return DeeperSupportRecommendation(
      type: DeeperSupportType.selfCompassion,
      title: '自我关怀与滋养',
      methodLabel: 'Self-Compassion & Savoring',
      theorySource: '源自自我关怀与正向心理学',
      shortDescription: '难受时，陪你停止自我攻击；美好时，帮你把这份好放大、留住。',
      stuckPoint: observed,
      groundedUnderstanding: '好事不只发生在你身上，更是被你发现、被你做成的——这一半功劳，记得认领。',
      oneSmallStep: '挑这段里最打动你的一个画面，闭上眼用 5 秒重过一遍：颜色、声音、温度，让它在身体里多停一会儿。',
      steadySentence: '我值得这样的好，也有能力一次次遇见它。',
      face: 'high',
      enoughSignal: enoughSignal,
      resonance: '这样的时刻，别急着翻篇——值得多停一会儿。',
      emotions: emotions,
      observedLabel: '你匆匆带过的好',
      observedValue: '「$observed」',
      truthLabel: '而这份好里',
      truthValue: '不只是运气刚好，里面有你的功劳：是你看见了它、接住了它。',
      microActionKind: 'savoring',
    );
  }

  final observed = _extractSentence(text, _selfAttackKeywords) ?? '是不是我不够好';
  return DeeperSupportRecommendation(
    type: DeeperSupportType.selfCompassion,
    title: '自我关怀与滋养',
    methodLabel: 'Self-Compassion & Savoring',
    theorySource: '源自自我关怀与正向心理学',
    shortDescription: '难受时，陪你停止自我攻击；美好时，帮你把这份好放大、留住。',
    stuckPoint: observed,
    groundedUnderstanding: '会这么快责怪自己，恰恰说明你在乎、也想做好——这份在乎是真的，“我不行”不是。',
    oneSmallStep: '把刚才那句最重的自我评价换个对象想想：如果是最好的朋友处在你的处境，你会怎么跟 TA 说？把那句话，说给自己。',
    steadySentence: '我可以又难、又不必责怪自己。',
    face: 'low',
    enoughSignal: enoughSignal,
    resonance: '已经够难受了，还要反过来怪自己——太难为自己了。',
    emotions: emotions,
    observedLabel: '你对自己说的话',
    observedValue: '「$observed」',
    truthLabel: '但其实',
    truthValue: '让你扛不住的是处境，不是你这个人；事情难，不等于你不行。',
    microActionKind: 'self_kindness',
  );
}

int _intensityScore(IntensityLevel level) {
  switch (level) {
    case IntensityLevel.veryLow:
      return 20;
    case IntensityLevel.low:
      return 40;
    case IntensityLevel.medium:
      return 60;
    case IntensityLevel.high:
      return 80;
    case IntensityLevel.veryHigh:
      return 95;
  }
}

/// 从原文里抽出第一句命中关键词的短句，用于翻转卡引用
String? _extractSentence(String text, List<String> keywords) {
  final segments = text
      .split(RegExp(r'[。！？!?；;\n]+'))
      .expand((part) => part.split(RegExp(r'[，,]')))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  for (final segment in segments) {
    final lower = segment.toLowerCase();
    if (keywords.any(lower.contains)) {
      return segment.length > 36 ? '${segment.substring(0, 36)}…' : segment;
    }
  }
  return null;
}

bool _containsAny(String text, List<String> keywords) {
  return keywords.any(text.contains);
}

class DeeperSupportScreen extends StatefulWidget {
  final DeepAnalysisResult analysis;

  /// 原始记录文本。传入且方法为「自我关怀与滋养」时，
  /// 进入页面会调用智能体生成正式拆解（先展示本地占位，返回后无感替换）。
  /// 从已保存结果打开时不传，不会重复调用。
  final String? transcription;

  /// 默认走 CozeAIService；测试或迁移服务端代理时可注入替代实现。
  final DeepAnalysisLoader? analysisLoader;

  const DeeperSupportScreen({
    super.key,
    required this.analysis,
    this.transcription,
    this.analysisLoader,
  });

  @override
  State<DeeperSupportScreen> createState() => _DeeperSupportScreenState();
}

class _DeeperSupportScreenState extends State<DeeperSupportScreen> {
  bool _actionDone = false;
  bool _loadingAgent = false;
  String? _agentError;
  late DeepAnalysisResult _analysis;

  DeepAnalysisResult get analysis => _analysis;

  @override
  void initState() {
    super.initState();
    _analysis = widget.analysis;
    _prepareAgentRequest();
  }

  void _prepareAgentRequest() {
    final transcription = widget.transcription?.trim();
    if (transcription == null || transcription.isEmpty) return;

    DeepAnalysisLoader? loader;
    if (widget.analysisLoader != null) {
      loader = widget.analysisLoader!;
    } else {
      if (getIt.isRegistered<CozeAIService>() &&
          EnvConfig.isDeepAnalysisConfiguredFor(widget.analysis.type)) {
        loader =
            (methodType, input) => getIt<CozeAIService>().generateDeepAnalysis(
                  methodType: methodType,
                  transcription: input,
                );
      }
    }

    if (loader == null) {
      _agentError = '这个分析方法暂时还没有配置好';
      return;
    }

    _loadingAgent = true;
    _fetchFromAgent(loader, transcription);
  }

  Future<void> _fetchFromAgent(
    DeepAnalysisLoader loader,
    String transcription,
  ) async {
    try {
      final result = await loader(widget.analysis.type, transcription);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _loadingAgent = false;
        _agentError = null;
      });
    } catch (e) {
      debugPrint('🫶 深入分析智能体调用失败: $e');
      if (!mounted) return;
      setState(() {
        _loadingAgent = false;
        _agentError = '这次没有生成成功，请再试一次';
      });
    }
  }

  void _retryAgentRequest() {
    final transcription = widget.transcription?.trim();
    if (transcription == null || transcription.isEmpty) return;

    final DeepAnalysisLoader? loader = widget.analysisLoader ??
        (getIt.isRegistered<CozeAIService>() &&
                EnvConfig.isDeepAnalysisConfiguredFor(widget.analysis.type)
            ? (methodType, input) =>
                getIt<CozeAIService>().generateDeepAnalysis(
                  methodType: methodType,
                  transcription: input,
                )
            : null);
    if (loader == null) return;

    setState(() {
      _loadingAgent = true;
      _agentError = null;
    });
    _fetchFromAgent(loader, transcription);
  }

  bool get _isStructured => analysis.hasStructuredBreakdown;

  bool get _isHighFace => analysis.face == 'high';

  /// observed 是否划删除线：只有「该被放下的内容」才划——
  /// 自我关怀低谷面的自我攻击、想法校准的错误结论；
  /// ACT 的念头（不对抗）、DBT 的情绪、BA 的身体信号都不划。
  bool get _strikeObserved =>
      analysis.face == 'low' ||
      analysis.type == DeeperSupportType.cognitiveReframe.name;

  Color get _bodyColor {
    if (!_isStructured) return const Color(0xFFF5F5F5);
    return _isHighFace ? const Color(0xFFFFF7E6) : const Color(0xFFF6F1EA);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${analysis.methodLabel} · ${analysis.theorySource}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF9A7A52),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 生成结果回来前只展示方法概述，不提前暴露本地占位拆解。
                  if (!_loadingAgent &&
                      _agentError == null &&
                      _isStructured &&
                      analysis.face != null)
                    _buildFacePill()
                  else
                    Text(
                      analysis.overview,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.65,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: _bodyColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: _buildAnalysisBody(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bodyColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                    key: const ValueKey('deep-analysis-complete-button'),
                    onPressed: _loadingAgent
                        ? null
                        : _agentError != null
                            ? _retryAgentRequest
                            : () => Navigator.of(context).pop(analysis),
                    style: TextButton.styleFrom(
                      backgroundColor: _loadingAgent
                          ? AppColors.accent.withValues(alpha: 0.45)
                          : AppColors.accent,
                      disabledBackgroundColor:
                          AppColors.accent.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _loadingAgent
                          ? '正在生成…'
                          : _agentError != null
                              ? '重新生成'
                              : '完成',
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildAnalysisBody() {
    if (_loadingAgent) return _buildLoadingState();
    if (_agentError != null) return _buildErrorState();
    return _isStructured ? _buildStructuredBody() : _buildClassicBody();
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '正在慢慢读你写的这条…',
              key: ValueKey('deep-analysis-loading-state'),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '分析完成后，结果会出现在这里',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.refresh_rounded,
              size: 28,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _agentError!,
              key: const ValueKey('deep-analysis-error-state'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 通用结构（CBT / ACT / DBT / BA） ----------

  Widget _buildClassicBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: '你真正卡住的地方',
          content: analysis.stuckPoint,
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: '更贴近你的理解',
          content: analysis.groundedUnderstanding,
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: '现在先做这一件小事',
          content: analysis.oneSmallStep,
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: '一句陪你站稳的话',
          content: analysis.steadySentence,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ---------- 结构化拆解（五方法智能体同构输出） ----------

  Widget _buildFacePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isHighFace ? const Color(0xFFFFEFC9) : AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _isHighFace ? '高光时刻 · 接住自己的好' : '低谷时刻 · 站回自己这边',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8D6A3B),
        ),
      ),
    );
  }

  Widget _buildStructuredBody() {
    final hasDetailedResult = analysis.emotions.isNotEmpty ||
        analysis.observedValue != null ||
        analysis.truthValue != null ||
        analysis.groundedUnderstanding.trim().isNotEmpty ||
        analysis.oneSmallStep.trim().isNotEmpty ||
        analysis.steadySentence.trim().isNotEmpty;

    if (!analysis.enoughSignal && !hasDetailedResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (analysis.resonance != null)
            _buildResonanceBubble(analysis.resonance!),
          const SizedBox(height: 12),
          _buildCard(
            child: const Text(
              '这几个字背后，应该还有更多。想再多说一点吗？回到记录里补两句，我再陪你看看。',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.resonance != null)
          _buildResonanceBubble(analysis.resonance!),
        if (analysis.emotions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: analysis.emotions.map(_buildEmotionChip).toList(),
          ),
        ],
        if (analysis.observedValue != null && analysis.truthValue != null) ...[
          const SizedBox(height: 12),
          _buildFlipCard(),
        ],
        const SizedBox(height: 12),
        _buildInsightCard(),
        const SizedBox(height: 12),
        _buildActionCard(),
        const SizedBox(height: 12),
        _buildSelfStatementCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildResonanceBubble(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          height: 1.7,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmotionChip(DeepEmotion emotion) {
    final fraction = (emotion.intensity.clamp(0, 100)) / 100.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emotion.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE7DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 34 * fraction,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 翻转卡：observed（弱化）→ truth（点亮）
  Widget _buildFlipCard() {
    final observedStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: const Color(0xFF9B9286),
      decoration:
          _strikeObserved ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: _strikeObserved ? const Color(0xFFB8AC9C) : null,
    );

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysis.observedLabel ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.observedValue ?? '',
            key: const ValueKey('deep-analysis-observed-value'),
            style: observedStyle,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            analysis.truthLabel ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8D6A3B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _isHighFace ? const Color(0xFFFFF3D6) : AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              analysis.truthValue ?? '',
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: AppColors.accent),
              SizedBox(width: 6),
              Text(
                '一句洞察',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            analysis.groundedUnderstanding,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    final isSavoringAction = analysis.microActionKind == 'savoring';
    const actionLabel = '试一下';
    const doneLabel = '为你开心';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSavoringAction
                    ? Icons.bookmark_add_outlined
                    : Icons.volunteer_activism_outlined,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              const Text(
                '现在试试',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            analysis.oneSmallStep,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() => _actionDone = !_actionDone),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _actionDone ? AppColors.accentLight : AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _actionDone ? doneLabel : actionLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _actionDone ? const Color(0xFF8D6A3B) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfStatementCard() {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '❝',
            style: TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                analysis.steadySentence,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF4A4A4A),
            ),
          ),
        ],
      ),
    );
  }
}
