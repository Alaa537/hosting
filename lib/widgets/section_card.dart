import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final Widget? trailing;

  const SectionCard({
    super.key, this.title, required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Expanded(child: Text(title!,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
        ],
        child,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(icon, size: 48, color: C.muted.withValues(alpha: .4)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: C.muted, fontSize: 14)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: C.muted, fontSize: 11)),
        ],
      ]),
    );
  }
}

class KVRow extends StatelessWidget {
  final String k;
  final Widget v;
  const KVRow({super.key, required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(k,
            style: const TextStyle(color: C.muted, fontSize: 12))),
        Expanded(child: v),
      ]),
    );
  }
}
