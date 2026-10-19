import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bootstrap.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';

class BannerStrip extends StatefulWidget {
  final BannerInfo banner;
  final VoidCallback? onDismiss;

  const BannerStrip({super.key, required this.banner, this.onDismiss});

  @override
  State<BannerStrip> createState() => _BannerStripState();
}

class _BannerStripState extends State<BannerStrip> {
  @override
  void initState() {
    super.initState();
    // تشغيل صوت الإشعار عند ظهور البانر
    AudioService.playNotification();
  }

  Color get _color {
    switch (widget.banner.color) {
      case 'warning': return C.warning;
      case 'error': return C.danger;
      case 'success': return C.success;
      case 'info': return C.info;
      default: return C.primary;
    }
  }

  IconData get _icon {
    switch (widget.banner.icon) {
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
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        // خلفية داكنة + حدود متوهجة لتبدو فخمة وليست رمادية
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: .8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: .25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _color.withValues(alpha: .15),
                Colors.transparent,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Icon(_icon, color: _color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.banner.text,
                  style: TextStyle(
                    color: _color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              if (widget.banner.actionUrl != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                  icon: Icon(Icons.open_in_new, color: _color),
                  onPressed: () async {
                    try {
                      await launchUrl(Uri.parse(widget.banner.actionUrl!),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                ),
              if (widget.onDismiss != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 18,
                  icon: const Icon(Icons.close, color: C.muted),
                  onPressed: widget.onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
