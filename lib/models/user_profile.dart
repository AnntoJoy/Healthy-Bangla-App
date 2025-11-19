class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String preferredLanguage;
  final int savedCount;
  final int readCount;
  final int daysActive;
  
  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.preferredLanguage,
    required this.savedCount,
    required this.readCount,
    required this.daysActive,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      preferredLanguage: json['preferred_language'] ?? 'en',
      savedCount: json['saved_count'] ?? 0,
      readCount: json['read_count'] ?? 0,
      daysActive: json['days_active'] ?? 0,
    );
  }
}