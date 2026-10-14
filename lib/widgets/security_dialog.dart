import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/security_service.dart';
import '../utils/constants.dart';

class SecurityBlockScreen extends StatelessWidget {
  final SecurityResult result;
  const SecurityBlockScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final d = _details();
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: d.$4.withValues(alpha: .12),
              border: Border.all(color: d.$4.withValues(alpha: .55), width: 2),
              boxShadow: [BoxShadow(color: d.$4.withValues(alpha: .35),
                  blurRadius: 40, spreadRadius: 6)],
            ),
            child: Center(child: Text(d.$1, style: const TextStyle(fontSize: 54))),
          ),
          const SizedBox(height: 26),
          Text(d.$2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: d.$4.withValues(alpha: .35)),
            ),
            child: Text(d.$3, textAlign: TextAlign.center,
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
        return ('🚫', 'VPN مكتشف', 'أوقف الـ VPN ثم أعد فتح التطبيق.', C.danger);
      case SecurityStatus.mitm:
        return ('🛡️', 'أداة مراقبة', 'أغلق HTTP Canary / Charles ثم أعد الفتح.', C.danger);
      case SecurityStatus.tampered:
        return ('⚠️', 'تطبيق معدّل', 'التوقيع غير مطابق. حمّل النسخة الأصلية.', C.danger);
      case SecurityStatus.ssl:
        return ('🔒', 'شهادة غير موثوقة', 'قد تكون هناك محاولة اعتراض للاتصال.', C.danger);
      case SecurityStatus.rooted:
        return ('🔓', 'الجهاز متجذّر', 'لا يمكن استخدام التطبيق على جهاز Rooted.', C.danger);
      case SecurityStatus.frida:
        return ('🎯', 'أداة تحليل مكتشفة', 'أغلق Frida وأعد فتح التطبيق.', C.danger);
      case SecurityStatus.emulator:
        return ('💻', 'محاكي مكتشف', 'التطبيق لا يعمل على المحاكيات.', C.danger);
      case SecurityStatus.debugger:
        return ('🐛', 'التطبيق تحت التصحيح', 'أغلق الـ Debugger وأعد الفتح.', C.danger);
      case SecurityStatus.xposed:
        return ('🧩', 'Xposed مكتشف', 'أزل Xposed Framework.', C.danger);
      case SecurityStatus.error:
        return ('⚠️', 'خطأ', result.message ?? 'تعذّر التحقق.', C.warning);
      case SecurityStatus.ok:
        return ('✅', 'OK', '', C.success);
    }
  }
}
