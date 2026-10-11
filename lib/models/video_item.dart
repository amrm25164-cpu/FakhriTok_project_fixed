class VideoItem {
  final String id;
  final String? userId;
  final String username;
  final String caption;
  final String videoUrl;
  final String avatarUrl;
  final String? localPath;
  final int likes;
  final int comments;
  final int shares;
  final bool isDemo;

  const VideoItem({
    required this.id,
    this.userId,
    required this.username,
    required this.caption,
    required this.videoUrl,
    required this.avatarUrl,
    this.localPath,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isDemo = true,
  });

  VideoItem copyWith({int? likes, int? comments, int? shares}) => VideoItem(
    id: id, userId: userId, username: username, caption: caption, videoUrl: videoUrl,
    avatarUrl: avatarUrl, localPath: localPath, likes: likes ?? this.likes,
    comments: comments ?? this.comments, shares: shares ?? this.shares,
    isDemo: isDemo,
  );
}
