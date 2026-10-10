import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/error_utils.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final username = _user.text.trim();
    final password = _pass.text;

    setState(() => _busy = true);
    final e = await context.read<AuthProvider>().login(username, password);
    if (!mounted) return;
    setState(() => _busy = false);

    if (e != null) {
      // Distinguish device-lock errors from bad credentials
      if (e.contains('الجهاز') || e.contains('device')) {
        _showError('الجهاز مقفل', e);
      } else {
        _showError('فشل تسجيل الدخول', 'اسم المستخدم أو كلمة المرور خطأ');
      }
      return;
    }
  }

  void _showError(String title, String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.danger.withValues(alpha: .15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.error_outline, color: C.danger, size: 32),
      ),
      title: Text(title, textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [C.primary, C.accent]).createShader(r),
                child: const Text('HOST PANEL',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
                        letterSpacing: 4, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              const Text('Control panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 48),
              const Text('تسجيل الدخول',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.person_outline, color: C.primary),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline, color: C.primary),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('دخول'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('إنشاء حساب جديد'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
