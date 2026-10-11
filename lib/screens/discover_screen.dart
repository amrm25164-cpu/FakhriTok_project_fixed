import 'package:flutter/material.dart';
import '../services/local_store.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _controller = TextEditingController();
  final _suggestions = ['football_daily', 'fakhri_editz', 'skills_world', 'goal_zone', 'real_madrid_fans'];
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _results = _suggestions;
  }

  void _search(String q) {
    setState(() => _results = _suggestions.where((s) => s.toLowerCase().contains(q.toLowerCase())).toList());
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اكتشف'), centerTitle: false),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(
        controller: _controller, onChanged: _search,
        decoration: InputDecoration(hintText: 'ابحث عن مستخدم...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF191919), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      )),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerRight, child: Text('حسابات مقترحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))),
      Expanded(child: _results.isEmpty ? const Center(child: Text('لا توجد نتائج')) : ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('@${_results[i]}'),
          subtitle: const Text('حساب مقترح · بيانات تجريبية'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ملفات المستخدمين الحقيقية تحتاج خادمًا وحسابات مسجلة.'))),
        ),
      )),
    ]),
  );
}
