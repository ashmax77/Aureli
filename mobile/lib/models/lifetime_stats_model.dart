class LifetimeStatsModel {
  final double totalEarned;
  final double totalSpent;
  final double totalSaved;
  final double netWorth;
  final int activeMonths;

  LifetimeStatsModel({
    required this.totalEarned,
    required this.totalSpent,
    required this.totalSaved,
    required this.netWorth,
    required this.activeMonths,
  });

  factory LifetimeStatsModel.fromJson(Map<String, dynamic> json) {
    return LifetimeStatsModel(
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      totalSaved: (json['totalSaved'] as num?)?.toDouble() ?? 0.0,
      netWorth: (json['netWorth'] as num?)?.toDouble() ?? 0.0,
      activeMonths: json['activeMonths'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEarned': totalEarned,
      'totalSpent': totalSpent,
      'totalSaved': totalSaved,
      'netWorth': netWorth,
      'activeMonths': activeMonths,
    };
  }
}
