import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bootstrap.dart';
import '../utils/constants.dart';

class BannerStrip extends StatelessWidget {
  final BannerInfo banner;
  final VoidCallback? onDismiss;

  const BannerStrip({super.key, required this.banner, this.onDismiss});

  Color get _color {
    switch (banner.color) {
      case 'warning': return C.warning;
      case 'error': return C.danger;
      case 'success': return C.success;
      case 'info': return C.info;
      default: return C.primary;
    }
  }

  IconData get _icon {
    switch (banner.icon) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'server': return Icons.dns_outlined;
      case 'gift': return Icons.card_giftcard;
      case 'download': return Icons.download_rounded;
      case 'info': return Icons.info_outline;
      default: return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _color.withValues(alpha: .18),
          _color.withValues(alpha: .06),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: .45)),
      ),
      child: Row(children: [
        Icon(_icon, color: _color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(banner.text,
            style: TextStyle(
              color: _color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ))),
        if (banner.actionUrl != null)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 18,
            icon: Icon(Icons.open_in_new, color: _color),
            onPressed: () async {
              try {
                await launchUrl(Uri.parse(banner.actionUrl!),
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        if (onDismiss != null)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 16,
            icon: const Icon(Icons.close, color: C.muted),
            onPressed: onDismiss,
          ),
      ]),
    );
  }
}
