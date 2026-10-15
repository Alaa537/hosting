import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/telegram_fab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            bottom: 180,  // ← فوق زر الرفع
            child: const TelegramFab(),
          ),
        ]),
      ),
    );
  }
}
