class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String? authorName;
  final String? authorProfileImageUrl;
  final String content;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName,
    this.authorProfileImageUrl,
    required this.content,
    required this.createdAt,
  });

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    final postId = (map['postid'] ?? map['postId'] ?? '').toString();
    final authorId = (map['authorid'] ?? map['authorId'] ?? '').toString();
    final authorName = (map['author_name'] ?? map['authorName'] ?? map['users_name'] ?? map['users_businessname'])?.toString();
    final authorProfileImageUrl = (map['author_profile_image_url'] ?? map['authorProfileImageUrl'] ?? map['users_avatar_url'])?.toString();
    final content = (map['content'] ?? map['text'] ?? '').toString();
    final created = map['createdat'] ?? map['createdAt'] ?? map['created_at'];

    return CommunityComment(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorProfileImageUrl: authorProfileImageUrl,
      content: content,
      createdAt: DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
