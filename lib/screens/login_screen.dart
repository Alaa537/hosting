import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
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
  String? _err;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    final e = await context.read<AuthProvider>().login(_user.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() { _busy = false; _err = e; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
                child: const Text('HOSTING',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
                        letterSpacing: 4, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text(auth.baseUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, fontSize: 11)),
              const SizedBox(height: 48),
              const Text('Sign in',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline, color: C.primary),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: C.primary),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              if (_err != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.danger.withValues(alpha: .4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: C.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_err!,
                        style: const TextStyle(color: C.danger, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('SIGN IN'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Create account'),
              ),
              TextButton(
                onPressed: () => _changeBase(auth),
                child: const Text('Change server URL', style: TextStyle(color: C.muted)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _changeBase(AuthProvider auth) async {
    final c = TextEditingController(text: auth.baseUrl);
    final r = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      title: const Text('Server URL'),
      content: TextField(controller: c, decoration: const InputDecoration()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
      ],
    ));
    if (r != null && r.isNotEmpty) await auth.setBase(r.trim());
  }
}
