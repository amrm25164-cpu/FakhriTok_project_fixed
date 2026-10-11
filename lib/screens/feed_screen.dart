import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_item.dart';
import '../services/local_store.dart';
import '../services/backend_api.dart';

const demoVideos = <VideoItem>[
  VideoItem(id: 'demo1', username: 'football_daily', caption: 'أجمل لحظات كرة القدم ⚽ #football #fyp', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4', avatarUrl: '', likes: 12800, comments: 352, shares: 81),
  VideoItem(id: 'demo2', username: 'fakhri_editz', caption: 'تجربة الفيديو العمودي في FakhriTok 🔥', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4', avatarUrl: '', likes: 8400, comments: 219, shares: 47),
];

class FeedScreen extends StatefulWidget {
  final List<VideoItem> uploadedVideos;
  const FeedScreen({super.key, required this.uploadedVideos});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late List<VideoItem> _videos;
  Set<String> _liked = {};
  Set<String> _saved = {};
  Set<String> _followed = {};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _videos = [...widget.uploadedVideos, ...demoVideos];
    _loadState();
    _loadRealFeed();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uploadedVideos.length != widget.uploadedVideos.length) {
      setState(() => _videos = [...widget.uploadedVideos, ...demoVideos]);
    }
  }


  Future<void> _loadRealFeed() async {
    try {
      final rows = await BackendApi.feed(limit: 20);
      if (!mounted || rows.isEmpty) return;
      final real = rows.map((row) => VideoItem(
        id: row['id']?.toString() ?? '',
        userId: row['userId']?.toString(),
        username: row['username']?.toString() ?? 'user',
        caption: row['caption']?.toString() ?? '',
        videoUrl: row['videoUrl']?.toString() ?? '',
        avatarUrl: row['avatarUrl']?.toString() ?? '',
        likes: (row['likes'] as num?)?.toInt() ?? 0,
        comments: (row['comments'] as num?)?.toInt() ?? 0,
        isDemo: false,
      )).where((v) => v.id.isNotEmpty && v.videoUrl.isNotEmpty).toList();
      if (real.isNotEmpty && mounted) setState(() => _videos = [...widget.uploadedVideos, ...real]);
    } catch (_) {
      // Keep clearly labeled demo feed if the backend is not configured/reachable.
    }
  }

  Future<void> _loadState() async {
    final liked = await LocalStore.liked();
    final saved = await LocalStore.saved();
    final followed = await LocalStore.followed();
    if (mounted) setState(() { _liked = liked; _saved = saved; _followed = followed; });
  }

  Future<void> _toggleLike(VideoItem v) async {
    final token = await BackendApi.token();
    if (!v.isDemo && token != null) {
      try {
        final result = await BackendApi.toggleLike(v.id);
        final liked = result['liked'] == true;
        setState(() {
          if (liked) { _liked.add(v.id); } else { _liked.remove(v.id); }
          _videos = _videos.map((x) => x.id == v.id ? x.copyWith(likes: (result['likes'] as num?)?.toInt() ?? x.likes) : x).toList();
        });
        await LocalStore.saveLiked(_liked);
        return;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الإعجاب على الخادم: $e')));
        return;
      }
    }
    setState(() {
      if (_liked.contains(v.id)) {
        _liked.remove(v.id);
        _videos = _videos.map((x) => x.id == v.id ? x.copyWith(likes: (x.likes - 1).clamp(0, 1 << 30).toInt()) : x).toList();
      } else {
        _liked.add(v.id);
        _videos = _videos.map((x) => x.id == v.id ? x.copyWith(likes: x.likes + 1) : x).toList();
      }
    });
    await LocalStore.saveLiked(_liked);
  }

  Future<void> _toggleSave(VideoItem v) async {
    final token = await BackendApi.token();
    if (!v.isDemo && token != null) {
      try {
        final result = await BackendApi.toggleSave(v.id);
        setState(() { if (result['saved'] == true) { _saved.add(v.id); } else { _saved.remove(v.id); } });
        await LocalStore.saveSaved(_saved);
        return;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الفيديو على الخادم: $e')));
        return;
      }
    }
    setState(() { if (!_saved.add(v.id)) _saved.remove(v.id); });
    await LocalStore.saveSaved(_saved);
  }

  Future<void> _toggleFollow(VideoItem v) async {
    final token = await BackendApi.token();
    if (!v.isDemo && token != null && v.userId != null) {
      try {
        final result = await BackendApi.follow(v.userId!);
        setState(() { if (result['following'] == true) { _followed.add(v.username); } else { _followed.remove(v.username); } });
        await LocalStore.saveFollowed(_followed);
        return;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث المتابعة: $e')));
        return;
      }
    }
    setState(() { if (!_followed.add(v.username)) _followed.remove(v.username); });
    await LocalStore.saveFollowed(_followed);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_followed.contains(v.username) ? 'تمت متابعة @${v.username}' : 'تم إلغاء متابعة @${v.username}')));
  }

  Future<List<String>> _commentsFor(VideoItem video) async {
    final token = await BackendApi.token();
    if (!video.isDemo && token != null) {
      final rows = await BackendApi.comments(video.id);
      return rows.map((r) => '@${r['username']}: ${r['body']}').toList();
    }
    return LocalStore.comments(video.id);
  }

  void _comments(VideoItem video) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF171717),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .62,
          child: Column(children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('التعليقات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Divider(height: 1),
            Expanded(child: FutureBuilder<List<String>>(
              future: _commentsFor(video),
              builder: (ctx, snap) {
                final comments = snap.data ?? [];
                if (comments.isEmpty) return const Center(child: Text('لا توجد تعليقات بعد'));
                return ListView.builder(itemCount: comments.length, itemBuilder: (_, i) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(comments[i])));
              },
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(children: [
                Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'اكتب تعليقًا...', border: OutlineInputBorder()))),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF25F4EE)), onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final token = await BackendApi.token();
                  if (!video.isDemo && token != null) {
                    try { await BackendApi.addComment(video.id, text); } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التعليق: $e')));
                      return;
                    }
                  } else {
                    await LocalStore.addComment(video.id, text);
                  }
                  controller.clear();
                  if (ctx.mounted) { Navigator.pop(ctx); _comments(video); }
                }),
              ]),
            )
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeVideos = _videos;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: activeVideos.isEmpty
          ? const Center(child: Text('لا توجد فيديوهات'))
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: activeVideos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _VideoPage(
                key: ValueKey(activeVideos[i].id),
                video: activeVideos[i],
                active: i == _index,
                liked: _liked.contains(activeVideos[i].id),
                saved: _saved.contains(activeVideos[i].id),
                followed: _followed.contains(activeVideos[i].username),
                onLike: () => _toggleLike(activeVideos[i]),
                onSave: () => _toggleSave(activeVideos[i]),
                onFollow: () => _toggleFollow(activeVideos[i]),
                onComments: () => _comments(activeVideos[i]),
              ),
            ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final VideoItem video;
  final bool active, liked, saved, followed;
  final VoidCallback onLike, onSave, onFollow, onComments;
  const _VideoPage({super.key, required this.video, required this.active, required this.liked, required this.saved, required this.followed, required this.onLike, required this.onSave, required this.onFollow, required this.onComments});
  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _error = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final v = widget.video;
      if (v.localPath != null) {
        _controller = VideoPlayerController.file(File(v.localPath!));
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(v.videoUrl));
      }
      await _controller!.initialize();
      await _controller!.setLooping(true);
      if (widget.active) await _controller!.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller?.value.isInitialized ?? false) {
      if (widget.active && !(oldWidget.active)) {
        _controller!.play();
      } else if (!widget.active && oldWidget.active) {
        _controller!.pause();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
    else if (widget.active) _controller?.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  String _count(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        onTap: () {
          final c = _controller;
          if (c == null || !c.value.isInitialized) return;
          setState(() => c.value.isPlaying ? c.pause() : c.play());
        },
        child: ColoredBox(
          color: const Color(0xFF151515),
          child: _error
            ? const Center(child: Icon(Icons.play_disabled, size: 56, color: Colors.white54))
            : (_controller?.value.isInitialized ?? false)
              ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)))
              : const Center(child: CircularProgressIndicator(color: Color(0xFF25F4EE))),
        ),
      ),
      Positioned(top: 12, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('لك  ', style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 16)),
        const Text('|', style: TextStyle(color: Colors.white38)),
        const SizedBox(width: 8),
        const Text('أتابعه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ])),
      Positioned(right: 10, bottom: 104, child: Column(children: [
        const CircleAvatar(radius: 25, backgroundColor: Color(0xFF222222), child: Icon(Icons.person, size: 30)),
        const SizedBox(height: 8),
        IconButton(onPressed: widget.onFollow, icon: Icon(widget.followed ? Icons.person_remove : Icons.add_circle, color: widget.followed ? Colors.white : const Color(0xFFFF2D55), size: 30)),
        const SizedBox(height: 12),
        IconButton(onPressed: widget.onLike, icon: Icon(widget.liked ? Icons.favorite : Icons.favorite_border, color: widget.liked ? const Color(0xFFFF2D55) : Colors.white, size: 34)),
        Text(_count(v.likes), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        IconButton(onPressed: widget.onComments, icon: const Icon(Icons.mode_comment_outlined, size: 30)),
        Text(_count(v.comments), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        IconButton(onPressed: widget.onSave, icon: Icon(widget.saved ? Icons.bookmark : Icons.bookmark_border, size: 30)),
        const Text('حفظ', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        IconButton(onPressed: () => Share.share('شاهد الفيديو على FakhriTok: ${v.caption}'), icon: const Icon(Icons.share, size: 28)),
        Text(_count(v.shares), style: const TextStyle(fontSize: 12)),
      ])),
      Positioned(left: 14, right: 78, bottom: 32, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('@${v.username}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(v.caption.isEmpty ? 'فيديو جديد على FakhriTok' : v.caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.music_note, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text(v.localPath != null ? 'الصوت الأصلي · فيديو من جهازك' : 'صوت تجريبي · FakhriTok', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        ]),
        if (v.isDemo) const Padding(padding: EdgeInsets.only(top: 5), child: Text('محتوى تجريبي', style: TextStyle(color: Colors.white60, fontSize: 10))),
      ])),
    ]);
  }
}
