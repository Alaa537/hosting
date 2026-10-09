import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (_, auth, __) {
      if (auth.state == AuthState.loading) {
        return Scaffold(
          body: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _logo(),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => LinearProgressIndicator(
                      value: _c.value,
                      minHeight: 3,
                      backgroundColor: C.border,
                      valueColor: const AlwaysStoppedAnimation(C.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Connecting…',
                  style: TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
        );
      }
      return auth.state == AuthState.loggedIn
          ? const HomeShell()
          : const LoginScreen();
    });
  }

  Widget _logo() => ShaderMask(
    shaderCallback: (r) => const LinearGradient(
      colors: [C.primary, C.accent],
    ).createShader(r),
    child: const Text(
      'HOSTING',
      style: TextStyle(
        fontSize: 42, fontWeight: FontWeight.w900,
        letterSpacing: 6, color: Colors.white,
      ),
    ),
  );
}
