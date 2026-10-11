import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/video_item.dart';
import '../services/local_store.dart';
import '../services/backend_api.dart';
import 'feed_screen.dart';
import 'discover_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final List<VideoItem> _uploads = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _upload() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final captionController = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('وصف الفيديو'),
        content: TextField(
          controller: captionController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اكتب وصفًا للفيديو...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, captionController.text.trim()), child: const Text('نشر محليًا')),
        ],
      ),
    );
    captionController.dispose();
    if (caption == null || !mounted) return;
    final username = await LocalStore.username();
    final token = await BackendApi.token();
    if (token != null) {
      try {
        final uploaded = await BackendApi.uploadVideo(filePath: file.path, caption: caption);
        setState(() {
          _uploads.insert(0, VideoItem(
            id: uploaded['id']?.toString() ?? 'upload_${DateTime.now().microsecondsSinceEpoch}',
            userId: uploaded['userId']?.toString(),
            username: uploaded['username']?.toString() ?? username,
            caption: uploaded['caption']?.toString() ?? caption,
            videoUrl: uploaded['videoUrl']?.toString() ?? '',
            avatarUrl: uploaded['avatarUrl']?.toString() ?? '',
            likes: (uploaded['likes'] as num?)?.toInt() ?? 0,
            comments: (uploaded['comments'] as num?)?.toInt() ?? 0,
            isDemo: false,
          ));
          _tab = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الفيديو إلى الخادم.')));
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الفيديو إلى الخادم: $e')));
        return;
      }
    }
    setState(() {
      _uploads.insert(0, VideoItem(
        id: 'upload_${DateTime.now().microsecondsSinceEpoch}',
        username: username,
        caption: caption,
        videoUrl: '',
        localPath: file.path,
        avatarUrl: '',
        isDemo: false,
      ));
      _tab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة الفيديو لهذا الجهاز فقط. سجّل الدخول واربط الخادم للنشر للآخرين.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(uploadedVideos: _uploads),
      const DiscoverScreen(),
      const InboxScreen(),
      ProfileScreen(uploadedVideos: _uploads, onUpload: _upload),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF101010),
        indicatorColor: const Color(0x3325F4EE),
        selectedIndex: _tab < 2 ? _tab : _tab + 1,
        onDestinationSelected: (i) {
          if (i == 2) {
            _upload();
            return;
          }
          setState(() => _tab = i > 2 ? i - 1 : i);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          const NavigationDestination(icon: Icon(Icons.search), label: 'اكتشف'),
          const NavigationDestination(icon: Icon(Icons.add_box_outlined, size: 28), label: 'نشر'),
          const NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الوارد'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}
