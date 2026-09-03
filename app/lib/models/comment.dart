class Comment {
  const Comment({
    required this.key,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  factory Comment.fromMap(String key, Map<dynamic, dynamic> map) {
    return Comment(
      key: key,
      text: map['text'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String key;
  final String text;
  final String authorId;
  final String authorName;
  final int createdAt;
}
