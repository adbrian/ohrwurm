import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../library/widgets.dart';
import '../packs/pack_display.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';

/// The session's pack names, in selection order.
String packNames(List<String> packIds, Map<String, Pack> packs) => [
  for (final id in packIds)
    if (packs[id] != null) packHeading(packInputOf(packs[id]!)) else id,
].join(' + ');

/// *also in K2 · NB1* (APP_SPEC 8): other packs by their short name. A pack of another level
/// than [packId]'s carries its level: *A2 K2*.
String alsoInLabel(List<String> packIds, String packId) {
  final level = _parse(packId)?.level;
  return packIds
      .map((id) {
        final p = _parse(id);
        if (p == null) return id;
        final short = '${p.kind == 'k' ? 'K' : 'NB'}${p.number}';
        return p.level == level ? short : '${p.level.toUpperCase()} $short';
      })
      .join(' · ');
}

({String level, String kind, int number})? _parse(String packId) {
  final m = RegExp(r'^([ab][12])_(k|nb)(\d+)$').firstMatch(packId);
  if (m == null) return null;
  return (level: m[1]!, kind: m[2]!, number: int.parse(m[3]!));
}

/// Back, the session's pack names, *Card 23 of 90 · shuffled* beneath, and an optional control on
/// the right (DESIGN 5).
class SessionHeader extends StatelessWidget {
  final String packs;
  final String detail;
  final VoidCallback onBack;
  final Widget? trailing;

  const SessionHeader({
    super.key,
    required this.packs,
    required this.detail,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: Row(
        children: [
          PlainIconButton(icon: AppIcons.back, tooltip: SessionCopy.back, onPressed: onBack),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  packs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.german(15),
                ),
                const SizedBox(height: 2),
                Text(detail, style: AppTextStyles.meta.copyWith(fontFeatures: AppText.tabular)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A pill toggle: accent border when on, divider border when off (DESIGN 5).
class PillToggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;

  const PillToggle({super.key, required this.label, required this.on, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: on ? AppColors.accent : AppColors.divider,
              width: AppBorder.interactive,
            ),
          ),
          child: Text(
            label,
            style: AppText.german(13).copyWith(color: on ? AppColors.accent : AppColors.neutral400),
          ),
        ),
      ),
    );
  }
}

/// A small outlined tag: *also in K2 · NB1* (DESIGN 5).
class OutlinedTag extends StatelessWidget {
  final String text;

  const OutlinedTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.divider, width: AppBorder.rule),
      ),
      child: Text(text, style: AppTextStyles.meta.copyWith(color: AppColors.neutral400)),
    );
  }
}

/// A rule fading out at both ends (DESIGN 5).
class FadingRule extends StatelessWidget {
  const FadingRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppBorder.rule,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x002C2C38), AppColors.divider, AppColors.divider, Color(0x002C2C38)],
          stops: [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }
}

/// Opacity 0.45 → 1 and back, about 1.1 s: the active line's mark and the status dot (DESIGN 5).
class Pulse extends StatefulWidget {
  final Widget child;
  final bool active;

  const Pulse({super.key, required this.child, this.active = true});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    lowerBound: 0.45,
    upperBound: 1,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _controller, child: widget.child);
}

/// The card follows the finger, tilting about `dx / 42` degrees and fading a little; past about
/// 90 px it flies off and [onSwipe] brings the next card (DESIGN 5). Both directions do the same.
/// A tap calls [onTap].
class SwipeCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipe;
  final VoidCallback? onTap;

  /// Changes when the card changes, so a new card arrives without the old one's offset.
  final Object cardKey;

  const SwipeCard({
    super.key,
    required this.child,
    required this.cardKey,
    this.onSwipe,
    this.onTap,
  });

  static const threshold = 90.0;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  double _dx = 0;
  late final _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  Animation<double>? _flight;

  /// The card flying off, kept as it was when it left.
  Widget? _leaving;

  @override
  void initState() {
    super.initState();
    _fly.addListener(() => setState(() => _dx = _flight!.value));
    _fly.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _leaving = null;
          _dx = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  void _end(DragEndDetails details, double width) {
    final v = details.primaryVelocity ?? 0;
    final past = _dx.abs() > SwipeCard.threshold || v.abs() > 900;
    if (past && widget.onSwipe != null) {
      final dir = _dx == 0 ? v.sign : _dx.sign;
      _leaving = widget.child;
      _flight = Tween(begin: _dx, end: dir * width * 1.2).animate(_fly);
      widget.onSwipe!();
      _fly.forward(from: 0);
    } else {
      _flight = Tween(begin: _dx, end: 0.0).animate(_fly);
      _fly.forward(from: 0).then((_) {
        if (mounted) setState(() => _dx = 0);
      });
    }
  }

  Widget _transformed(Widget child, double dx) => Transform.translate(
    offset: Offset(dx, 0),
    child: Transform.rotate(
      angle: dx / 42 * pi / 180,
      child: Opacity(opacity: 1 - min(dx.abs() / 600, 0.35), child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leaving = _leaving;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onHorizontalDragUpdate: widget.onSwipe == null
              ? null
              : (d) {
                  if (_leaving == null) setState(() => _dx += d.delta.dx);
                },
          onHorizontalDragEnd: widget.onSwipe == null ? null : (d) => _end(d, constraints.maxWidth),
          child: Stack(
            children: [
              // The next card waits beneath the one leaving.
              Positioned.fill(
                child: leaving == null
                    ? _transformed(
                        KeyedSubtree(key: ValueKey(widget.cardKey), child: widget.child),
                        _dx,
                      )
                    : KeyedSubtree(key: ValueKey(widget.cardKey), child: widget.child),
              ),
              if (leaving != null) Positioned.fill(child: _transformed(leaving, _dx)),
            ],
          ),
        );
      },
    );
  }
}

/// A surface card, 16 px radius (DESIGN, Shape).
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color border;

  const SurfaceCard({super.key, required this.child, this.border = AppColors.divider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: border, width: AppBorder.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
