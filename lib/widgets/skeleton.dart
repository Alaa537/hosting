import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.surfaceHi,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
            duration: 1400.ms,
            color: C.primary.withValues(alpha: .12));
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border),
        ),
        child: Row(children: [
          const Skeleton(width: 46, height: 46, radius: 12),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(width: 180, height: 14),
              SizedBox(height: 8),
              Skeleton(width: 120, height: 11),
            ],
          )),
        ]),
      ),
    );
  }
}
