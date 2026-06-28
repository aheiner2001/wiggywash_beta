import 'package:flutter/material.dart';

import '../theme.dart';

/// A number that smoothly counts up/down to its target when [value] changes.
/// Pass a [format] to render currency, percentages, plain ints, etc.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// A friendly empty-state block: icon + title + supporting line.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.padding = const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
  });

  final IconData icon;
  final String title;
  final String? message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.blueSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.navy),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center, style: TextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// A shimmering placeholder block used for loading skeletons.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 8,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.35 + (_c.value * 0.4);
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.hairline, AppColors.blueSoft, t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A lightweight bar chart (no external deps) for short trends like daily
/// revenue. Bars scale to the max value; the tallest is highlighted.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 120,
    this.barColor = AppColors.blue,
    this.highlightColor = AppColors.navy,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color barColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final frac = maxV <= 0 ? 0.0 : values[i] / maxV;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: frac),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, f, _) => Container(
                                height: (c.maxHeight * f).clamp(2.0, c.maxHeight),
                                decoration: BoxDecoration(
                                  color: (values[i] >= maxV && maxV > 0)
                                      ? highlightColor
                                      : barColor,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i < labels.length ? labels[i] : '',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A card-shaped skeleton used while a list/section first loads.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3});
  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonBox(height: 20, width: 160),
          const SizedBox(height: 14),
          for (var i = 0; i < lines; i++) ...[
            SkeletonBox(height: 14, width: i.isEven ? double.infinity : 220),
            if (i != lines - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
