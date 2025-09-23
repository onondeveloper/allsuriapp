class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    final postId = (map['postid'] ?? map['postId'] ?? '').toString();
    final authorId = (map['authorid'] ?? map['authorId'] ?? '').toString();
    final content = (map['content'] ?? map['text'] ?? '').toString();
    final created = map['createdat'] ?? map['createdAt'] ?? map['created_at'];

    return CommunityComment(
      id: id,
      postId: postId,
      authorId: authorId,
      content: content,
      createdAt: DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
