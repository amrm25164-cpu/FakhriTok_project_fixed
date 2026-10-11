import 'package:flutter/material.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الوارد')),
    body: ListView(children: const [
      ListTile(leading: CircleAvatar(child: Icon(Icons.favorite, color: Colors.pink)), title: Text('النشاط'), subtitle: Text('ستظهر الإعجابات والتعليقات الجديدة بعد ربط الحساب بخادم حقيقي.'), isThreeLine: true),
      Divider(height: 1),
      ListTile(leading: CircleAvatar(child: Icon(Icons.people_alt)), title: Text('المتابعون'), subtitle: Text('إشعارات المتابعة تحتاج إلى Backend.'), isThreeLine: true),
      Divider(height: 1),
      ListTile(leading: CircleAvatar(child: Icon(Icons.message_outlined)), title: Text('الرسائل'), subtitle: Text('الرسائل الخاصة غير مفعلة في نسخة العرض المحلية.'), isThreeLine: true),
    ]),
  );
}
