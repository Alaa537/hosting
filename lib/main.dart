import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_fortress/app_fortress.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/telegram_fab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة درع الحماية (app_fortress)
  await AppFortress.initialize(
    config: SecurityConfig.production(), // وضع الإنتاج: صرامة عالية
    onThreatDetected: (threat) {
      // هنا يتم تسجيل التهديدات أو التعامل معها
      debugPrint("Threat detected: ${threat.name}");
    },
  );

  runApp(const HostingApp());
}

class HostingApp extends StatelessWidget {
  const HostingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      // إحاطة التطبيق بالكامل بـ SecurityGate
      // أي محاولة للعبث بالتطبيق أو بيئته ستوقف التطبيق من الفتح
      child: SecurityGate(
        child: MaterialApp(
          title: 'HOST PANEL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const SplashScreen(),
          builder: (context, child) => Stack(children: [
            if (child != null) child,
            Positioned(
              right: 16,
              bottom: 90,
              child: const TelegramFab(),
            ),
          ]),
        ),
      ),
    );
  }
}
