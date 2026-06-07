import 'package:flutter/material.dart';

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
    );
  }
}

DeeperSupportType recommendedDeeperSupportType({
  required String transcription,
  required NVCAnalysis analysis,
}) {
  final text = [
    transcription,
    analysis.observation,
    analysis.request ?? '',
    analysis.insight ?? '',
    analysis.feelings.map((item) => item.feeling).join(' '),
    analysis.needs.map((item) => item.need).join(' '),
  ].join(' ').toLowerCase();

  if (_containsAny(text, const [
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
  ])) {
    return DeeperSupportType.selfCompassion;
  }

  if (_containsAny(text, const [
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
  ])) {
    return DeeperSupportType.boundarySupport;
  }

  if (_containsAny(text, const [
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
  ])) {
    return DeeperSupportType.gentleRecovery;
  }

  if (_containsAny(text, const [
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
  ])) {
    return DeeperSupportType.releaseControl;
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
      return const DeeperSupportRecommendation(
        type: DeeperSupportType.selfCompassion,
        title: '站回自己这边',
        methodLabel: 'Self-Compassion',
        theorySource: '源自自我同情与慈悲聚焦取向',
        shortDescription: '帮助你把责任与自我否定分开，在困难里重新站回自己这一边。',
        stuckPoint: '你现在最难受的，不只是事情本身，而是你开始把过载和失序解释成“是不是我不够好”。',
        groundedUnderstanding: '一个已经很在意、也很想做好的人，才会这么快责怪自己。自责说明你重视，不等于你真的做得很差。',
        oneSmallStep: '先把今天脑子里最重的一句自我评价写下来，再把它改成一句更贴近事实的话，比如“我现在是太满了，不是没能力”。',
        steadySentence: '我可以先停止追责自己，再决定下一步怎么做。',
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

bool _containsAny(String text, List<String> keywords) {
  return keywords.any(text.contains);
}

class DeeperSupportScreen extends StatelessWidget {
  final DeepAnalysisResult analysis;

  const DeeperSupportScreen({
    super.key,
    required this.analysis,
  });

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
                color: const Color(0xFFF5F5F5),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
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
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
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
                    onPressed: () => Navigator.of(context).pop(analysis),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accent,
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
  }) {
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
