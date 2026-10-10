import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bootstrap.dart';
import '../providers/auth_provider.dart';
import '../services/security_monitor.dart';
import '../services/security_service.dart';
import '../utils/constants.dart';
import '../widgets/announcement_dialog.dart';
import '../widgets/security_dialog.dart';
import '../widgets/update_dialog.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'kill_switch_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  bool _bootstrapChecked = false;

  /// Current blocking security failure (null = OK)
  SecurityResult? _blocked;

  @override
  void initState() {
    super.initState();
    // Wire the global monitor → repaint on failure/recovery.
    SecurityMonitor.I.onFailure = (r) {
      if (!mounted) return;
      setState(() => _blocked = r);
    };
    SecurityMonitor.I.onRecovered = () {
      if (!mounted) return;
      setState(() => _blocked = null);
    };
    // Start monitoring.
    SecurityMonitor.I.start();
  }

  @override
  void dispose() {
    _c.dispose();
    SecurityMonitor.I.onFailure = null;
    SecurityMonitor.I.onRecovered = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Security block takes top priority.
    if (_blocked != null) {
      return SecurityBlockScreen(result: _blocked!);
    }

    return Consumer<AuthProvider>(builder: (_, auth, __) {
      if (auth.state == AuthState.blocked) {
        return KillSwitchScreen(
          reason: auth.blockedReason ?? '',
          onRetry: () async {
            await auth.recheckKillSwitch();
            setState(() => _bootstrapChecked = false);
          },
        );
      }

      if (auth.state == AuthState.loading) {
        return Scaffold(body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _logo(),
            const SizedBox(height: 32),
            SizedBox(width: 200, child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => LinearProgressIndicator(
                  value: _c.value, minHeight: 3,
                  backgroundColor: C.border,
                  valueColor: const AlwaysStoppedAnimation(C.primary),
                ),
              ),
            )),
            const SizedBox(height: 12),
            const Text('جارٍ الاتصال…',
                style: TextStyle(color: C.muted, fontSize: 12)),
          ],
        )));
      }

      if (!_bootstrapChecked && auth.state == AuthState.loggedIn) {
        _bootstrapChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _runBootstrap(auth));
      }

      return auth.state == AuthState.loggedIn
          ? const HomeShell()
          : const LoginScreen();
    });
  }

  Future<void> _runBootstrap(AuthProvider auth) async {
    final bs = auth.bootstrap_ ?? await auth.loadBootstrap();
    if (!mounted || bs == null) return;

    if (bs.maintenance) {
      await showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.build_circle_outlined, color: C.warning, size: 40),
        title: const Text('وضع الصيانة',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'الخدمة في وضع الصيانة حالياً. بعض العمليات قد تفشل.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.5),
        ),
        actions: [Center(child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('فهمت'),
        ))],
      ));
      if (!mounted) return;
    }

    if (bs.update != null) {
      final ok = await showUpdateDialog(context, bs.update!);
      if (!ok) return;
    }

    for (final modal in bs.modals) {
      if (!mounted) break;
      await showAnnouncementDialog(context, modal, onDismiss: () async {
        try { await auth.api!.dismissModal(modal.id); } catch (_) {}
      });
    }
  }

  Widget _logo() => ShaderMask(
    shaderCallback: (r) => const LinearGradient(
      colors: [C.primary, C.accent],
    ).createShader(r),
    child: const Text('HOST PANEL',
        style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900,
            letterSpacing: 6, color: Colors.white)),
  );
}
