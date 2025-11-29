class Ad {
  final String id;
  final String? title;
  final String imageUrl;
  final String? linkUrl;
  final bool isActive;
  final String location;

  Ad({
    required this.id,
    this.title,
    required this.imageUrl,
    this.linkUrl,
    this.isActive = true,
    this.location = 'dashboard_banner',
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      linkUrl: json['link_url']?.toString(),
      isActive: json['is_active'] == true,
      location: json['location']?.toString() ?? 'dashboard_banner',
    );
  }
}

