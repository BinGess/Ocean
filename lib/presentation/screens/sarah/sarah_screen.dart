import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/sarah_letter.dart';
import '../../bloc/sarah/sarah_bloc.dart';
import '../../bloc/sarah/sarah_event.dart';
import '../../bloc/sarah/sarah_state.dart';

class SarahScreen extends StatefulWidget {
  const SarahScreen({super.key});

  @override
  State<SarahScreen> createState() => _SarahScreenState();
}

class _SarahScreenState extends State<SarahScreen> {
  final Set<String> _expandedLetterIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SarahBloc>().add(const SarahLoadRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SarahColors.page,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SarahBloc, SarahState>(
          builder: (context, state) {
            if (state.status == SarahStatus.loading && state.letters.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _SarahColors.active,
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SarahHeader(totalCount: state.totalCount),
                ),
                if (state.weeklyLetter != null) ...[
                  const SliverToBoxAdapter(
                    child: _SectionTitle(title: '本周来信'),
                  ),
                  SliverToBoxAdapter(
                    child: _CurrentWeekLetterCard(
                      letter: state.weeklyLetter!,
                      isExpanded:
                          _expandedLetterIds.contains(state.weeklyLetter!.id),
                      onToggle: () => _toggleLetter(state.weeklyLetter!),
                    ),
                  ),
                ],
                if (state.pastLetters.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionTitle(title: '往期信件', centered: true),
                  ),
                  SliverList.separated(
                    itemCount: state.pastLetters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final letter = state.pastLetters[index];
                      return _PastLetterTile(
                        letter: letter,
                        isExpanded: _expandedLetterIds.contains(letter.id),
                        onToggle: () => _toggleLetter(letter),
                      );
                    },
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleLetter(SarahLetter letter) {
    setState(() {
      if (_expandedLetterIds.contains(letter.id)) {
        _expandedLetterIds.remove(letter.id);
      } else {
        _expandedLetterIds.add(letter.id);
        if (!letter.isRead) {
          context.read<SarahBloc>().add(SarahLetterRead(letterId: letter.id));
        }
      }
    });
  }
}

class _SarahHeader extends StatelessWidget {
  const _SarahHeader({
    required this.totalCount,
  });

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'From Sarah',
                  style: AppTypography.tabPageTitle,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '共 $totalCount 封信',
                  style: AppTypography.sectionSubtle.copyWith(
                    color: _SarahColors.mutedGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Stay with you',
            style: AppTypography.bodyQuote.copyWith(
              color: _SarahColors.mutedGold,
              fontSize: 20,
              fontFamily: AppTypography.serifFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.centered = false,
  });

  final String title;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28, centered ? 28 : 0, 28, 14),
      child: Row(
        children: [
          if (centered)
            const Expanded(child: Divider(color: _SarahColors.line)),
          if (centered) const SizedBox(width: 12),
          Text(
            title,
            style: AppTypography.sectionTitle.copyWith(
              color: _SarahColors.active,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: _SarahColors.line)),
        ],
      ),
    );
  }
}

class _CurrentWeekLetterCard extends StatelessWidget {
  const _CurrentWeekLetterCard({
    required this.letter,
    required this.isExpanded,
    required this.onToggle,
  });

  final SarahLetter letter;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _LetterPaper(
      letter: letter,
      expanded: isExpanded,
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LetterDate(letter: letter),
          const SizedBox(height: 22),
          _LetterBody(
            letter: letter,
            expanded: isExpanded,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          _ToggleText(
            expanded: isExpanded,
            expandText: '查看全部',
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

class _PastLetterTile extends StatelessWidget {
  const _PastLetterTile({
    required this.letter,
    required this.isExpanded,
    required this.onToggle,
  });

  final SarahLetter letter;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: _LetterPaper(
        letter: letter,
        expanded: isExpanded,
        compact: !isExpanded,
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: isExpanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LetterDate(letter: letter),
                  const SizedBox(height: 18),
                  _LetterBody(letter: letter, expanded: true),
                  const SizedBox(height: 8),
                  _ToggleText(
                    expanded: true,
                    expandText: '展开',
                    onTap: onToggle,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LetterDate(letter: letter, compact: true),
                        const SizedBox(height: 7),
                        Text(
                          letter.resolvedPreviewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyPrimary.copyWith(
                            color: _SarahColors.ink,
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '展开',
                    style: AppTypography.actionLabel.copyWith(
                      color: _SarahColors.active,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LetterPaper extends StatelessWidget {
  const _LetterPaper({
    required this.letter,
    required this.child,
    required this.margin,
    this.expanded = false,
    this.compact = false,
  });

  final SarahLetter letter;
  final Widget child;
  final EdgeInsets margin;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9F8F78).withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: _PaperPainter(compact: compact),
            child: Stack(
              children: [
                if (!compact)
                  Positioned(
                    top: 28,
                    right: 12,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.28,
                        child: _SarahIllustration(
                          letter: letter,
                          size: 128,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 44 : 54,
                    compact ? 25 : 34,
                    26,
                    compact ? 24 : 30,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
          if (!letter.isRead)
            Positioned(
              top: 22,
              right: 24,
              child: Container(
                key: ValueKey('sarah-unread-dot-${letter.id}'),
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _SarahColors.unread,
                  shape: BoxShape.circle,
                  border: Border.all(color: _SarahColors.active, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LetterBody extends StatelessWidget {
  const _LetterBody({
    required this.letter,
    required this.expanded,
    this.maxLines,
  });

  final SarahLetter letter;
  final bool expanded;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        if (expanded) {
          return const LinearGradient(
            colors: [Colors.black, Colors.black],
          ).createShader(bounds);
        }
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.7, 1],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          letter.content,
          maxLines: expanded ? null : maxLines,
          overflow: expanded ? TextOverflow.visible : TextOverflow.fade,
          style: AppTypography.bodyPrimary.copyWith(
            color: _SarahColors.ink,
            height: 1.6,
            fontSize: 15.0,
            fontWeight: FontWeight.w400,
            fontFamily: AppTypography.serifFamily,
          ),
        ),
      ),
    );
  }
}

class _LetterDate extends StatelessWidget {
  const _LetterDate({
    required this.letter,
    this.compact = false,
  });

  final SarahLetter letter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatLetterDate(letter),
      style: AppTypography.pageMeta.copyWith(
        color: _SarahColors.mutedGold,
        fontSize: compact ? 16 : 17,
        fontFamily: AppTypography.serifFamily,
      ),
    );
  }

  String _formatLetterDate(SarahLetter letter) {
    final start = letter.weekStart;
    final end = letter.weekEnd;
    if (start != null && end != null && letter.type != LetterType.welcome) {
      return '${DateFormat('M月d日').format(start)} - ${DateFormat('M月d日').format(end)}';
    }
    return '${DateFormat('yyyy年M月d日').format(letter.createdAt)}，${_weekday(letter.createdAt)}';
  }

  String _weekday(DateTime date) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[date.weekday - 1];
  }
}

class _ToggleText extends StatelessWidget {
  const _ToggleText({
    required this.expanded,
    required this.expandText,
    required this.onTap,
  });

  final bool expanded;
  final String expandText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          expanded ? '收起' : expandText,
          style: AppTypography.actionLabel.copyWith(
            color: _SarahColors.active,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SarahIllustration extends StatelessWidget {
  const _SarahIllustration({
    required this.letter,
    this.size = 92,
  });

  final SarahLetter letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      letter.illustrationAssetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return CustomPaint(
          size: Size(size, size),
          painter: _SarahPlaceholderPainter(),
        );
      },
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, paper);

    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF8F2E8), Colors.white],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 18));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 18), topPaint);

    final linePaint = Paint()
      ..color = _SarahColors.rule
      ..strokeWidth = 0.7;
    for (double y = 30; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = _SarahColors.marginLine
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(38, 0),
      Offset(38, size.height),
      marginPaint,
    );

    final foldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFE5D9C7).withValues(alpha: compact ? 0.18 : 0.28),
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 18, size.width, 18));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - 18, size.width, 18), foldPaint);

    final border = Paint()
      ..color = const Color(0xFFE8DFD1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) {
    return oldDelegate.compact != compact;
  }
}

class _SarahPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B271F)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.34, size.height * 0.16,
          size.width * 0.58, size.height * 0.24)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.34,
          size.width * 0.68, size.height * 0.56)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.76,
          size.width * 0.34, size.height * 0.68);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.82),
      Offset(size.width * 0.72, size.height * 0.82),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SarahColors {
  static const page = Color(0xFFF5F0E8);
  static const active = Color(0xFF8A7655);
  static const mutedGold = Color(0xFFA18E6B);
  static const ink = Color(0xFF2E2A22);
  static const line = Color(0xFFD9CDBB);
  static const rule = Color(0xFFECE7DF);
  static const marginLine = Color(0xFFE6A08A);
  static const unread = Color(0xFFD45E35);
}
