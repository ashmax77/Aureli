enum OnboardingStatus { NOT_STARTED, COMPLETED }

class UserModel {
  final int? id;
  final String firebaseUid;
  final String email;
  final OnboardingStatus onboardingStatus;
  final DateTime? onboardingCompletedAt;

  UserModel({
    this.id,
    required this.firebaseUid,
    required this.email,
    required this.onboardingStatus,
    this.onboardingCompletedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      firebaseUid: json['firebaseUid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      onboardingStatus: json['onboardingStatus'] == 'COMPLETED'
          ? OnboardingStatus.COMPLETED
          : OnboardingStatus.NOT_STARTED,
      onboardingCompletedAt: json['onboardingCompletedAt'] != null
          ? DateTime.parse(json['onboardingCompletedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'onboardingStatus': onboardingStatus.toString().split('.').last,
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
    };
  }
}
