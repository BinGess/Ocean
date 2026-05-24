import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/ocean_account_service.dart';
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
  StreamSubscription<void>? _accountDataSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SarahBloc>().add(const SarahLoadRequested());
      }
    });
    // Re-sync letters whenever account state changes (login, logout, deletion).
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      _accountDataSubscription =
          getIt<OceanAccountDataRefreshService>().changes.listen((_) {
        if (!mounted) return;
        context.read<SarahBloc>().add(const SarahLoadRequested());
      });
    }
  }

  @override
  void dispose() {
    _accountDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SarahColors.page,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<SarahBloc, SarahState>(
          // Auto-expand the latest letter the first time letters load
          listenWhen: (previous, current) =>
              previous.letters.isEmpty && current.letters.isNotEmpty,
          listener: (context, state) {
            final latest = state.weeklyLetter ??
                (state.pastLetters.isNotEmpty ? state.pastLetters.first : null);
            if (latest != null) {
              setState(() => _expandedLetterIds.add(latest.id));
              if (!latest.isRead) {
                context
                    .read<SarahBloc>()
                    .add(SarahLetterRead(letterId: latest.id));
              }
            }
          },
          builder: (context, state) {
            if (state.status == SarahStatus.loading && state.letters.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _SarahColors.active,
                ),
              );
            }

            // The featured (newest) letter: weeklyLetter if present,
            // otherwise the first past letter.
            final featured =
                state.weeklyLetter ?? state.pastLetters.firstOrNull;

            // Archive = everything that isn't the featured letter.
            // When weeklyLetter exists, pastLetters are already the archive.
            // When it doesn't, skip the first past letter (shown as featured).
            final archive = state.weeklyLetter != null
                ? state.pastLetters
                : (state.pastLetters.length > 1
                    ? state.pastLetters.sublist(1)
                    : <SarahLetter>[]);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SarahHeader(totalCount: state.totalCount),
                ),

                // ── Featured letter (always first, no section label) ─
                if (featured != null) ...[
                  if (state.weeklyLetter != null)
                    // Keep "本周来信" label only when there's a real weekly letter
                    const SliverToBoxAdapter(
                      child: _SectionTitle(title: '本周来信'),
                    ),
                  SliverToBoxAdapter(
                    child: _CurrentWeekLetterCard(
                      letter: featured,
                      isExpanded: _expandedLetterIds.contains(featured.id),
                      onToggle: () => _toggleLetter(featured),
                      onDelete: () => _showDeleteSheet(context, featured),
                    ),
                  ),
                ],

                // ── "往期信件" divider + archive ─────────────────────
                if (archive.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionTitle(title: '往期信件', centered: true),
                  ),
                  SliverList.separated(
                    itemCount: archive.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final letter = archive[index];
                      return _PastLetterTile(
                        letter: letter,
                        isExpanded: _expandedLetterIds.contains(letter.id),
                        onToggle: () => _toggleLetter(letter),
                        onDelete: () => _showDeleteSheet(context, letter),
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

  void _showDeleteSheet(BuildContext context, SarahLetter letter) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteLetterSheet(
        letter: letter,
        onConfirm: () {
          Navigator.of(context).pop();
          context
              .read<SarahBloc>()
              .add(SarahLetterDeleteRequested(letterId: letter.id));
        },
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
    required this.onDelete,
  });

  final SarahLetter letter;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: _LetterPaper(
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
            _ToggleArrow(
              expanded: isExpanded,
              onTap: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _PastLetterTile extends StatelessWidget {
  const _PastLetterTile({
    required this.letter,
    required this.isExpanded,
    required this.onToggle,
    required this.onDelete,
  });

  final SarahLetter letter;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onLongPress: onDelete,
      child: Semantics(
        button: true,
        label: isExpanded ? '收起 Sarah 信件' : '展开 Sarah 信件',
        // Same visual layout as _CurrentWeekLetterCard — illustration +
        // date + multi-line body + toggle button, no compact mode.
        child: _LetterPaper(
          letter: letter,
          expanded: isExpanded,
          margin: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LetterDate(letter: letter),
              SizedBox(height: isExpanded ? 18 : 22),
              _LetterBody(
                letter: letter,
                expanded: isExpanded,
                maxLines: 4,
              ),
              _ToggleArrow(
                expanded: isExpanded,
                onTap: onToggle,
              ),
            ],
          ),
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
  });

  final SarahLetter letter;
  final Widget child;
  final EdgeInsets margin;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C8260).withValues(alpha: 0.13),
            blurRadius: 16,
            offset: const Offset(0, 5),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF9C8260).withValues(alpha: 0.07),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: const _PaperPainter(),
            child: Stack(
              children: [
                Positioned(
                  top: 28,
                  right: 14,
                  child: IgnorePointer(
                    child: _SarahIllustration(
                      letter: letter,
                      size: 88,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 34, 26, 18),
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
                  border: Border.all(color: _SarahColors.paper, width: 1.5),
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
  const _LetterDate({required this.letter});

  final SarahLetter letter;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatLetterDate(letter),
      style: AppTypography.pageMeta.copyWith(
        color: _SarahColors.mutedGold,
        fontSize: 17,
        fontFamily: AppTypography.serifFamily,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }

  String _formatLetterDate(SarahLetter letter) {
    if (letter.type != LetterType.welcome) {
      final range = _resolvePeriodRange(letter);
      return '${DateFormat('yy.M.d').format(range.start)} - ${DateFormat('M.d').format(range.end)}';
    }
    // e.g. "26.5.20 周三"
    return '${DateFormat('yy.M.d').format(letter.createdAt)} ${_weekday(letter.createdAt)}';
  }

  DateTimeRange _resolvePeriodRange(SarahLetter letter) {
    final start = letter.weekStart;
    final end = letter.weekEnd;
    if (start != null && end != null) {
      return DateTimeRange(start: start, end: end);
    }
    if (start != null) {
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    }
    if (end != null) {
      return DateTimeRange(
        start: end.subtract(const Duration(days: 6)),
        end: end,
      );
    }

    final fallbackStart = _weekStartFor(letter.createdAt);
    return DateTimeRange(
      start: fallbackStart,
      end: fallbackStart.add(const Duration(days: 6)),
    );
  }

  DateTime _weekStartFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _weekday(DateTime date) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[date.weekday - 1];
  }
}

class _ToggleArrow extends StatelessWidget {
  const _ToggleArrow({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 0, 2),
          child: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: _SarahColors.active,
            ),
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
  const _PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()
      ..color = _SarahColors.paper
      ..isAntiAlias = true;
    canvas.drawRect(Offset.zero & size, paper);

    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF8EDD8), _SarahColors.paper],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 24));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 24), topPaint);

    _drawPaperFibers(canvas, size);
    _drawSoftTopEdge(canvas, size);

    final linePaint = Paint()
      ..color = _SarahColors.rule.withValues(alpha: 0.78)
      ..strokeWidth = 0.48
      ..isAntiAlias = true;
    final lastRuleY = size.height - 30;
    for (double y = 30; y < lastRuleY; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = _SarahColors.marginLine.withValues(alpha: 0.52)
      ..strokeWidth = 0.65
      ..isAntiAlias = true;
    canvas.drawLine(
      const Offset(30, 4),
      Offset(30, size.height - 8),
      marginPaint,
    );

    // Use transparent paper color (not Colors.transparent which is transparent BLACK
    // and causes dark fringe artifacts during gradient interpolation)
    final foldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x00FFFDF8), // transparent paper white — no black tint
          const Color(0xFFF8F0E3).withValues(alpha: 0.13),
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 24, size.width, 24));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - 24, size.width, 24), foldPaint);

    _drawSoftBottomEdge(canvas, size);

    final border = Paint()
      ..color = _SarahColors.paperBorder.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(0.5, size.height - 3)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 0.5, size.height - 3);
    canvas.drawPath(path, border);
  }

  void _drawPaperFibers(Canvas canvas, Size size) {
    final fiberPaint = Paint()
      ..color = _SarahColors.paperFiber.withValues(alpha: 0.10)
      ..strokeWidth = 0.38
      ..strokeCap = StrokeCap.round;
    const count = 46;
    for (var i = 0; i < count; i += 1) {
      final x = ((i * 47) % size.width).toDouble();
      final y = 12 + ((i * 31) % (size.height - 24)).toDouble();
      final length = 4 + (i % 5).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x + length, y + 0.25), fiberPaint);
    }
  }

  void _drawSoftTopEdge(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = _SarahColors.paperEdge.withValues(alpha: 0.18)
      ..strokeWidth = 0.55;
    for (double x = 0; x < size.width; x += 8) {
      final dip = ((x ~/ 8) % 3) * 0.35;
      canvas.drawLine(Offset(x, 0.5 + dip), Offset(x + 5, 0.7), edgePaint);
    }
  }

  void _drawSoftBottomEdge(Canvas canvas, Size size) {
    // Only warm highlights at the bottom edge — no dark fibers that create shadow artifacts
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFFCF5).withValues(alpha: 0.88)
      ..strokeWidth = 0.6
      ..isAntiAlias = true;

    for (double x = 0; x < size.width; x += 9) {
      final lift = ((x ~/ 9) % 4) * 0.28;
      canvas.drawLine(
        Offset(x, size.height - 3.4 + lift),
        Offset(x + 6, size.height - 3.1),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) => false;
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

// ── Delete confirmation bottom sheet ────────────────────────────────────────

class _DeleteLetterSheet extends StatelessWidget {
  const _DeleteLetterSheet({
    required this.letter,
    required this.onConfirm,
  });

  final SarahLetter letter;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _buildDateLabel();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _SarahColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Letter info ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Column(
              children: [
                const Text(
                  '删除这封信',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _SarahColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _SarahColors.mutedGold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '删除后无法恢复，本地和服务端记录都将被清除。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0x802E2A22), // ink @ 50%
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: _SarahColors.line.withValues(alpha: 0.6)),

          // ── Delete action ────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onConfirm,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text(
                '删除',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD44C3C),
                ),
              ),
            ),
          ),

          Divider(height: 1, color: _SarahColors.line.withValues(alpha: 0.6)),

          // ── Cancel ───────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text(
                '取消',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: _SarahColors.active,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _buildDateLabel() {
    if (letter.type != LetterType.welcome) {
      final range = _resolvePeriodRange();
      return '${DateFormat('yy.M.d').format(range.start)} - ${DateFormat('M.d').format(range.end)}';
    }

    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[letter.createdAt.weekday - 1];
    return '${DateFormat('yy.M.d').format(letter.createdAt)} $wd';
  }

  DateTimeRange _resolvePeriodRange() {
    final start = letter.weekStart;
    final end = letter.weekEnd;
    if (start != null && end != null) {
      return DateTimeRange(start: start, end: end);
    }
    if (start != null) {
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    }
    if (end != null) {
      return DateTimeRange(
        start: end.subtract(const Duration(days: 6)),
        end: end,
      );
    }

    final day = DateTime(
      letter.createdAt.year,
      letter.createdAt.month,
      letter.createdAt.day,
    );
    final fallbackStart =
        day.subtract(Duration(days: day.weekday - DateTime.monday));
    return DateTimeRange(
      start: fallbackStart,
      end: fallbackStart.add(const Duration(days: 6)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SarahColors {
  static const page = Color(0xFFF5F0E8);
  static const paper = Color(0xFFFFFDF8);
  static const active = Color(0xFF8A7655);
  static const mutedGold = Color(0xFFA18E6B);
  static const ink = Color(0xFF2E2A22);
  static const line = Color(0xFFD9CDBB);
  static const rule =
      Color(0xFFBFAE9C); // deeper warm tan for visible ruled lines
  static const marginLine = Color(0xFFECC6BA);
  static const paperBorder = Color(0xFFEDE4D7);
  static const paperFiber = Color(0xFFCDBFA8);
  static const paperEdge = Color(0xFFD8C9B3);
  static const unread = Color(0xFFD45E35);
}
