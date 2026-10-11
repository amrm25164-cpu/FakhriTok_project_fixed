import 'package:flutter/material.dart';
import '../services/backend_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _username.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await BackendApi.register(username: _username.text.trim(), email: _email.text.trim(), password: _password.text);
      } else {
        await BackendApi.login(identity: _email.text.trim(), password: _password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'إنشاء حساب' : 'تسجيل الدخول')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.play_circle_fill, size: 76, color: Color(0xFF25F4EE)),
      const SizedBox(height: 12),
      const Text('FakhriTok', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      if (_register) ...[
        TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().length < 3) ? 'اكتب اسمًا من 3 أحرف على الأقل' : null),
        const SizedBox(height: 12),
      ],
      TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني أو اسم المستخدم', prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()), validator: (v) => (v == null || v.length < 8) ? 'كلمة المرور 8 أحرف على الأقل' : null),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 18),
      FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.all(12), child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? 'إنشاء الحساب' : 'دخول'))),
      TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'لديك حساب؟ سجّل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا')),
      const SizedBox(height: 8),
      const Text('يتطلب الاتصال بخادم FakhriTok مُشغّل ومُهيّأ.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]))))),
  );
}
