import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/local_store.dart';
import '../services/backend_api.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final List<VideoItem> uploadedVideos;
  final VoidCallback onUpload;
  const ProfileScreen({super.key, required this.uploadedVideos, required this.onUpload});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = 'fakhri_user';
  final _editController = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final u = await LocalStore.username();
    if (mounted) setState(() => _username = u);
  }
  Future<void> _editName() async {
    _editController.text = _username;
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تعديل اسم المستخدم'),
      content: TextField(controller: _editController, decoration: const InputDecoration(prefixText: '@', hintText: 'username')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, _editController.text.trim().replaceAll(' ', '_')), child: const Text('حفظ')),
      ],
    ));
    if (result != null && result.isNotEmpty) {
      await LocalStore.setUsername(result);
      if (mounted) setState(() => _username = result);
    }
  }
  Future<void> _configureServer() async {
    final controller = TextEditingController(text: await BackendApi.baseUrl());
    if (!mounted) return;
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('عنوان خادم FakhriTok'),
      content: TextField(controller: controller, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'http://192.168.1.5:8000', helperText: 'على الموبايل استخدم IP الخادم على الشبكة، وليس localhost.')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('حفظ'))],
    ));
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await BackendApi.setBaseUrl(result);
    try {
      await BackendApi.health();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاتصال بالخادم بنجاح.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ العنوان، لكن الاتصال فشل: $e')));
    }
  }

  Future<void> _account() async {
    final current = await BackendApi.currentUser();
    if (!mounted) return;
    if (current != null) {
      final action = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.account_circle), title: Text('@${current['username'] ?? 'user'}'), subtitle: const Text('حساب متصل بالخادم')),
        ListTile(leading: const Icon(Icons.logout), title: const Text('تسجيل الخروج'), onTap: () => Navigator.pop(ctx, 'logout')),
      ])));
      if (action == 'logout') { await BackendApi.logout(); if (mounted) setState(() {}); }
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() { _editController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الملف الشخصي'), actions: [IconButton(onPressed: _editName, icon: const Icon(Icons.edit_outlined))]),
    body: ListView(children: [
      const SizedBox(height: 18),
      const Center(child: CircleAvatar(radius: 44, backgroundColor: Color(0xFF202020), child: Icon(Icons.person, size: 52))),
      const SizedBox(height: 12),
      Center(child: Text('@$_username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
      const SizedBox(height: 4),
      const Center(child: Text('ملف محلي · غير متصل بحساب سحابي', style: TextStyle(color: Colors.white60, fontSize: 12))),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _stat('الفيديوهات', '${widget.uploadedVideos.length}'),
        _stat('المتابعون', '0'),
        _stat('الإعجابات', '0'),
      ]),
      const SizedBox(height: 20),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: FilledButton.icon(onPressed: widget.onUpload, icon: const Icon(Icons.add), label: const Text('رفع فيديو'))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
        ListTile(leading: const Icon(Icons.cloud_outlined), title: const Text('اتصال بالخادم'), subtitle: const Text('إعداد عنوان API لتفعيل البيانات المشتركة'), onTap: _configureServer, trailing: const Icon(Icons.chevron_left)),
        ListTile(leading: const Icon(Icons.login), title: const Text('الحساب'), subtitle: const Text('تسجيل الدخول أو إنشاء حساب بالخادم'), onTap: _account, trailing: const Icon(Icons.chevron_left)),
      ])),
      const Padding(padding: EdgeInsets.all(16), child: Text('فيديوهاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      if (widget.uploadedVideos.isEmpty)
        const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لم تنشر فيديوهات بعد'))),
      ...widget.uploadedVideos.map((v) => ListTile(leading: const Icon(Icons.video_library_outlined), title: Text(v.caption.isEmpty ? 'فيديو بدون وصف' : v.caption), subtitle: const Text('محفوظ على هذا الجهاز فقط'))),
    ]),
  );

  Widget _stat(String title, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(title, style: const TextStyle(color: Colors.white60)),
  ]);
}
