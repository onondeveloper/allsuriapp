class AdminStatistics {
  final String id;
  final DateTime date;
  final int totalUsers;
  final int totalBusinessUsers;
  final int totalCustomers;
  final int totalEstimates;
  final int completedEstimates;
  final int pendingEstimates;
  final double totalRevenue;
  final double averageEstimateAmount;
  final Map<String, int> estimatesByRegion;
  final Map<String, int> estimatesByService;
  final List<BusinessBilling> businessBillings;

  AdminStatistics({
    required this.id,
    required this.date,
    required this.totalUsers,
    required this.totalBusinessUsers,
    required this.totalCustomers,
    required this.totalEstimates,
    required this.completedEstimates,
    required this.pendingEstimates,
    required this.totalRevenue,
    required this.averageEstimateAmount,
    required this.estimatesByRegion,
    required this.estimatesByService,
    required this.businessBillings,
  });

  factory AdminStatistics.fromJson(Map<String, dynamic> json) {
    return AdminStatistics(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      totalUsers: json['totalUsers'] ?? 0,
      totalBusinessUsers: json['totalBusinessUsers'] ?? 0,
      totalCustomers: json['totalCustomers'] ?? 0,
      totalEstimates: json['totalEstimates'] ?? 0,
      completedEstimates: json['completedEstimates'] ?? 0,
      pendingEstimates: json['pendingEstimates'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      averageEstimateAmount: (json['averageEstimateAmount'] ?? 0).toDouble(),
      estimatesByRegion: Map<String, int>.from(json['estimatesByRegion'] ?? {}),
      estimatesByService: Map<String, int>.from(json['estimatesByService'] ?? {}),
      businessBillings: (json['businessBillings'] as List<dynamic>?)
              ?.map((e) => BusinessBilling.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'totalUsers': totalUsers,
      'totalBusinessUsers': totalBusinessUsers,
      'totalCustomers': totalCustomers,
      'totalEstimates': totalEstimates,
      'completedEstimates': completedEstimates,
      'pendingEstimates': pendingEstimates,
      'totalRevenue': totalRevenue,
      'averageEstimateAmount': averageEstimateAmount,
      'estimatesByRegion': estimatesByRegion,
      'estimatesByService': estimatesByService,
      'businessBillings': businessBillings.map((e) => e.toJson()).toList(),
    };
  }
}

class BusinessBilling {
  final String businessId;
  final String businessName;
  final String region;
  final int bidCount;
  final int winCount;
  final double winRate;
  final double monthlyRevenue;
  final List<String> services;
  final DateTime lastActivity;

  BusinessBilling({
    required this.businessId,
    required this.businessName,
    required this.region,
    required this.bidCount,
    required this.winCount,
    required this.winRate,
    required this.monthlyRevenue,
    required this.services,
    required this.lastActivity,
  });

  factory BusinessBilling.fromJson(Map<String, dynamic> json) {
    return BusinessBilling(
      businessId: json['businessId'] ?? '',
      businessName: json['businessName'] ?? '',
      region: json['region'] ?? '',
      bidCount: json['bidCount'] ?? 0,
      winCount: json['winCount'] ?? 0,
      winRate: (json['winRate'] ?? 0).toDouble(),
      monthlyRevenue: (json['monthlyRevenue'] ?? 0).toDouble(),
      services: List<String>.from(json['services'] ?? []),
      lastActivity: DateTime.parse(json['lastActivity'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'region': region,
      'bidCount': bidCount,
      'winCount': winCount,
      'winRate': winRate,
      'monthlyRevenue': monthlyRevenue,
      'services': services,
      'lastActivity': lastActivity.toIso8601String(),
    };
  }
} 