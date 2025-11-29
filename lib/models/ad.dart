class Ad {
  final String id;
  final String? title;
  final String imageUrl;
  final String? linkUrl;
  final bool isActive;

  Ad({
    required this.id,
    this.title,
    required this.imageUrl,
    this.linkUrl,
    this.isActive = true,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      linkUrl: json['link_url']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}

