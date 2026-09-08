import 'package:flutter/material.dart';

/// A shimmer-style skeleton placeholder used while content loads.
///
/// Replaces generic CircularProgressIndicator with a modern Facebook-
/// style skeleton that mimics the final content's layout.
///
/// Usage:
///   Skeleton(width: 120, height: 16)  // a line of text
///   Skeleton.box(width: double.infinity, height: 80)  // a card
///   Skeleton.circle(size: 40)  // an avatar
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
  });

  const Skeleton.box({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  const Skeleton.circle({
    super.key,
    required this.width,
    this.height = 0,
    this.borderRadius = 0,
  }) : assert(width > 0);

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          width: widget.width,
          height: widget.height > 0
              ? widget.height
              : widget.width, // for circle
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, t * 0.5),
            borderRadius: widget.borderRadius == 0
                ? null
                : BorderRadius.circular(widget.borderRadius),
            shape: widget.borderRadius == 0 ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
    );
  }
}

/// A skeleton placeholder for a transaction row.
class TransactionSkeletonRow extends StatelessWidget {
  const TransactionSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Skeleton.circle(width: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 120, height: 14),
                SizedBox(height: 8),
                Skeleton(width: 80, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          Skeleton(width: 60, height: 14),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for a dashboard summary card.
class SummaryCardSkeleton extends StatelessWidget {
  const SummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 100, height: 12),
          const SizedBox(height: 12),
          const Skeleton(width: 180, height: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(width: 60, height: 10),
                    SizedBox(height: 6),
                    Skeleton(width: 80, height: 14),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(width: 60, height: 10),
                    SizedBox(height: 6),
                    Skeleton(width: 80, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
