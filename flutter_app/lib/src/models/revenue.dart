class RevenueBreakdownItem {
  const RevenueBreakdownItem({
    required this.label,
    required this.orderCount,
    required this.amount,
  });

  final String label;
  final int orderCount;
  final double amount;
}

class RevenueSummary {
  const RevenueSummary({
    required this.transactionCount,
    required this.grossRevenue,
    required this.refundedRevenue,
    required this.netRevenue,
    required this.averageTicket,
    required this.pendingRefundCount,
    required this.pendingRefundAmount,
    required this.cashNet,
    required this.cardNet,
    required this.upiNet,
    required this.otherNet,
    required this.paymentBreakdown,
    required this.serviceBreakdown,
    required this.machineTypeBreakdown,
    required this.topMachineBreakdown,
  });

  final int transactionCount;
  final double grossRevenue;
  final double refundedRevenue;
  final double netRevenue;
  final double averageTicket;
  final int pendingRefundCount;
  final double pendingRefundAmount;
  final double cashNet;
  final double cardNet;
  final double upiNet;
  final double otherNet;
  final List<RevenueBreakdownItem> paymentBreakdown;
  final List<RevenueBreakdownItem> serviceBreakdown;
  final List<RevenueBreakdownItem> machineTypeBreakdown;
  final List<RevenueBreakdownItem> topMachineBreakdown;
}

class DayEndCheckout {
  const DayEndCheckout({
    required this.id,
    required this.businessDate,
    required this.closedAt,
    required this.closedByName,
    required this.transactionCount,
    required this.grossRevenue,
    required this.refundedRevenue,
    required this.netRevenue,
    required this.cashNet,
    required this.digitalNet,
    required this.openingCash,
    required this.expectedDrawerCash,
    required this.countedDrawerCash,
    required this.cashVariance,
    required this.pendingRefundCount,
    required this.pendingRefundAmount,
    this.notes,
  });

  final int id;
  final DateTime businessDate;
  final DateTime closedAt;
  final String closedByName;
  final int transactionCount;
  final double grossRevenue;
  final double refundedRevenue;
  final double netRevenue;
  final double cashNet;
  final double digitalNet;
  final double openingCash;
  final double expectedDrawerCash;
  final double countedDrawerCash;
  final double cashVariance;
  final int pendingRefundCount;
  final double pendingRefundAmount;
  final String? notes;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'businessDate': businessDate.toIso8601String(),
      'closedAt': closedAt.toIso8601String(),
      'closedByName': closedByName,
      'transactionCount': transactionCount,
      'grossRevenue': grossRevenue,
      'refundedRevenue': refundedRevenue,
      'netRevenue': netRevenue,
      'cashNet': cashNet,
      'digitalNet': digitalNet,
      'openingCash': openingCash,
      'expectedDrawerCash': expectedDrawerCash,
      'countedDrawerCash': countedDrawerCash,
      'cashVariance': cashVariance,
      'pendingRefundCount': pendingRefundCount,
      'pendingRefundAmount': pendingRefundAmount,
      'notes': notes,
    };
  }

  factory DayEndCheckout.fromJson(Map<String, dynamic> json) {
    return DayEndCheckout(
      id: json['id'] as int,
      businessDate: DateTime.parse(json['businessDate'] as String),
      closedAt: DateTime.parse(json['closedAt'] as String),
      closedByName: json['closedByName'] as String,
      transactionCount: json['transactionCount'] as int,
      grossRevenue: (json['grossRevenue'] as num).toDouble(),
      refundedRevenue: (json['refundedRevenue'] as num).toDouble(),
      netRevenue: (json['netRevenue'] as num).toDouble(),
      cashNet: (json['cashNet'] as num).toDouble(),
      digitalNet: (json['digitalNet'] as num).toDouble(),
      openingCash: (json['openingCash'] as num).toDouble(),
      expectedDrawerCash: (json['expectedDrawerCash'] as num).toDouble(),
      countedDrawerCash: (json['countedDrawerCash'] as num).toDouble(),
      cashVariance: (json['cashVariance'] as num).toDouble(),
      pendingRefundCount: json['pendingRefundCount'] as int,
      pendingRefundAmount: (json['pendingRefundAmount'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }
}
