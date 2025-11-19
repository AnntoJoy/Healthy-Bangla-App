class HealthEvent {
  final String id;
  final String title;
  final String? description;
  final String lang;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? venue;
  final String? coverImage;
  final double? distanceMeters;
  
  HealthEvent({
    required this.id,
    required this.title,
    this.description,
    required this.lang,
    required this.startsAt,
    required this.endsAt,
    this.venue,
    this.coverImage,
    this.distanceMeters,
  });
  
  factory HealthEvent.fromJson(Map<String, dynamic> json) {
    return HealthEvent(
      id: json['id'] ?? json['event_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      lang: json['lang'] ?? 'en',
      startsAt: DateTime.parse(json['starts_at']),
      endsAt: DateTime.parse(json['ends_at']),
      venue: json['venue'],
      coverImage: json['cover_image'],
      distanceMeters: json['distance_meters']?.toDouble(),
    );
  }
}