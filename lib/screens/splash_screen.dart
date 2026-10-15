import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _progressCtrl;

  bool _bootstrapChecked = false;
  SecurityResult? _blocked;
  double _progress = 0;
  String _status = 'تهيئة الحماية';

  @override
  void initState() {
    super.initState();

    // Background animated glow
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    // Rotating rings
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    // Logo entrance
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    // Progress bar
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..forward();

    _simulateSteps();

    // Wire security monitor
    SecurityMonitor.I.onFailure = (r) {
      if (!mounted) return;
      setState(() => _blocked = r);
    };
    SecurityMonitor.I.onRecovered = () {
      if (!mounted) return;
      setState(() => _blocked = null);
    };
    SecurityMonitor.I.start();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ringCtrl.dispose();
    _logoCtrl.dispose();
    _progressCtrl.dispose();
    SecurityMonitor.I.onFailure = null;
    SecurityMonitor.I.onRecovered = null;
    super.dispose();
  }

  Future<void> _simulateSteps() async {
    const steps = [
      ('تهيئة الحماية', 0.10, 400),
      ('التحقق من التوقيع', 0.35, 600),
      ('كشف التهديدات', 0.55, 500),
      ('الاتصال بالسيرفر', 0.75, 600),
      ('تجهيز الواجهة', 0.95, 400),
      ('جاهز', 1.00, 300),
    ];
    for (final s in steps) {
      if (!mounted) return;
      setState(() { _status = s.$1; _progress = s.$2; });
      await Future.delayed(Duration(milliseconds: s.$3));
    }
  }

  @override
  Widget build(BuildContext context) {
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

      if (auth.state == AuthState.loading) return _splashView();

      if (!_bootstrapChecked && auth.state == AuthState.loggedIn) {
        _bootstrapChecked = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _runBootstrap(auth));
      }

      return auth.state == AuthState.loggedIn
          ? const HomeShell()
          : const LoginScreen();
    });
  }

  // ============================================================
  //  SPLASH VIEW
  // ============================================================
  Widget _splashView() {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF05050C),
      body: Stack(children: [
        // 1) Animated background glows
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) {
            final t = _bgCtrl.value * 2 * math.pi;
            return Stack(children: [
              _blob(
                cx: size.width * (.3 + .2 * math.cos(t)),
                cy: size.height * (.3 + .15 * math.sin(t * 1.3)),
                radius: 260,
                color: C.primary.withValues(alpha: .35),
              ),
              _blob(
                cx: size.width * (.7 + .15 * math.sin(t * 1.1)),
                cy: size.height * (.65 + .2 * math.cos(t)),
                radius: 240,
                color: C.accent.withValues(alpha: .35),
              ),
              _blob(
                cx: size.width * (.5 + .25 * math.sin(t * .7)),
                cy: size.height * (.5 + .1 * math.cos(t * .9)),
                radius: 200,
                color: const Color(0xFF6F5FFF).withValues(alpha: .25),
              ),
            ]);
          },
        ),

        // 2) Rotating rings
        Center(
          child: AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, __) {
              return Transform.rotate(
                angle: _ringCtrl.value * 2 * math.pi,
                child: SizedBox(
                  width: 280, height: 280,
                  child: CustomPaint(
                    painter: _RingsPainter(
                      primary: C.primary,
                      accent: C.accent,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 3) Logo + text + progress
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              FadeTransition(
                opacity: CurvedAnimation(
                    parent: _logoCtrl, curve: const Interval(0, .6)),
                child: ScaleTransition(
                  scale: Tween<double>(begin: .5, end: 1).animate(
                      CurvedAnimation(
                          parent: _logoCtrl,
                          curve: const Interval(0, .8,
                              curve: Curves.elasticOut))),
                  child: _logoMark(),
                ),
              ),
              const SizedBox(height: 26),

              // Title gradient
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [C.primary, C.accent, C.primary],
                  stops: [0, .5, 1],
                ).createShader(r),
                child: const Text(
                  'HOST PANEL',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: Colors.white,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 700.ms, delay: 300.ms)
                  .slideY(begin: .3, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 6),
              const Text(
                'بوت استضافة ذكي',
                style: TextStyle(
                  color: C.muted,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: 700.ms, delay: 600.ms),

              const SizedBox(height: 54),

              // Progress
              SizedBox(
                width: 240,
                child: Column(children: [
                  // Bar
                  Stack(children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      widthFactor: _progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [C.primary, C.accent]),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                                color: C.primary.withValues(alpha: .7),
                                blurRadius: 10,
                                spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // Status
                  Row(children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor:
                            const AlwaysStoppedAnimation(C.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: C.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text('${(_progress * 100).round()}%',
                        style: const TextStyle(
                          color: C.primary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                        )),
                  ]),
                ]),
              ).animate().fadeIn(duration: 700.ms, delay: 800.ms),
            ],
          ),
        ),

        // 4) Bottom watermark
        Positioned(
          left: 0, right: 0, bottom: 32,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: C.success, shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: C.success.withValues(alpha: .8),
                        blurRadius: 8, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('نظام الحماية مُفعّل',
                  style: TextStyle(
                      color: C.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5)),
            ]),
            const SizedBox(height: 6),
            Text('v1.0.0 · ${const String.fromEnvironment('BUILD', defaultValue: 'release')}',
                style: TextStyle(
                  color: C.muted.withValues(alpha: .5),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                )),
          ]).animate().fadeIn(duration: 900.ms, delay: 1200.ms),
        ),
      ]),
    );
  }

  Widget _blob(
      {required double cx,
      required double cy,
      required double radius,
      required Color color}) {
    return Positioned(
      left: cx - radius,
      top: cy - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color,
            color.withValues(alpha: .15),
            Colors.transparent,
          ], stops: const [0, .5, 1]),
        ),
      ),
    );
  }

  Widget _logoMark() {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [C.primary, C.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: C.primary.withValues(alpha: .55),
              blurRadius: 40, spreadRadius: 6),
          BoxShadow(
              color: C.accent.withValues(alpha: .35),
              blurRadius: 60, spreadRadius: 10),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Color(0xFF05050C),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.rocket_launch_rounded,
              color: Colors.white, size: 54),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .boxShadow(
          begin: BoxShadow(
              color: C.primary.withValues(alpha: .4),
              blurRadius: 30, spreadRadius: 4),
          end: BoxShadow(
              color: C.accent.withValues(alpha: .7),
              blurRadius: 55, spreadRadius: 10),
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }

  // ============================================================
  //  BOOTSTRAP SEQUENCE (same as before)
  // ============================================================
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
}

// ============================================================
//  CUSTOM PAINTER — animated rings
// ============================================================
class _RingsPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  _RingsPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Ring 1 — dashed
    final p1 = Paint()
      ..color = primary.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const segments = 24;
    final r1 = size.width / 2;
    for (int i = 0; i < segments; i++) {
      final start = (i * 2 * math.pi / segments);
      final sweep = (2 * math.pi / segments) * .5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r1),
        start, sweep, false, p1,
      );
    }

    // Ring 2 — solid with glow
    final p2 = Paint()
      ..color = accent.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r1 - 22),
      -math.pi / 4, math.pi * 1.4, false, p2,
    );

    // Ring 3 — thin
    final p3 = Paint()
      ..color = primary.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r1 - 44, p3);

    // Dots
    final pDot = Paint()..color = accent;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawCircle(
        Offset(center.dx + (r1 - 22) * math.cos(a),
               center.dy + (r1 - 22) * math.sin(a)),
        2.5, pDot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => false;
}
