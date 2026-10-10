import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/security_service.dart';
import '../utils/constants.dart';

/// Non-dismissible dialog shown when security check fails.
class SecurityBlockScreen extends StatelessWidget {
  final SecurityResult result;
  const SecurityBlockScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, title, desc, color) = _details();
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .12),
              border: Border.all(color: color.withValues(alpha: .55), width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .35),
                  blurRadius: 40, spreadRadius: 6)],
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 54))),
          ),
          const SizedBox(height: 26),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .35)),
            ),
            child: Text(desc, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70,
                    fontSize: 14, height: 1.7)),
          ),
          const SizedBox(height: 22),
          TextButton.icon(
            onPressed: () async {
              try {
                await launchUrl(Uri.parse('https://t.me/ahrgq'),
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.telegram, color: C.primary),
            label: const Text('تواصل مع الدعم',
                style: TextStyle(color: C.primary)),
          ),
        ]),
      ))),
    );
  }

  (String, String, String, Color) _details() {
    switch (result.status) {
      case SecurityStatus.vpn:
        return ('🚫', 'VPN مكتشف',
            'لا يمكن استخدام التطبيق أثناء تشغيل VPN.\n'
            'أوقف الـ VPN ثم أعد فتح التطبيق.', C.danger);
      case SecurityStatus.mitm:
        return ('🛡️', 'أداة مراقبة مكتشفة',
            'تم كشف أداة تعترض الشبكة (مثل HTTP Canary / Charles).\n'
            'أغلقها ثم أعد فتح التطبيق.', C.danger);
      case SecurityStatus.tampered:
        return ('⚠️', 'تطبيق معدّل',
            'توقيع هذا التطبيق غير مطابق للتوقيع الرسمي.\n'
            'حمّل النسخة الأصلية من القناة الرسمية.', C.danger);
      case SecurityStatus.ssl:
        return ('🔒', 'خطأ في شهادة الاتصال',
            'شهادة الاتصال غير موثوقة.\n'
            'قد تكون هناك محاولة اعتراض للاتصال.', C.danger);
      case SecurityStatus.error:
        return ('⚠️', 'خطأ في التحقق',
            result.message ?? 'تعذّر التحقق من التطبيق.', C.warning);
      case SecurityStatus.ok:
        return ('✅', 'OK', '', C.success);
    }
  }
}
