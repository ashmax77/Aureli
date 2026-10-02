class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final bool isUnlocked;
  final String? unlockedAt;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconKey': iconKey,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt,
    };
  }
}
