class PricingDiscountType {
  static const percent = 'PERCENT';
  static const fixed = 'FIXED';
}

class PricingLineType {
  static const machine = 'MACHINE';
  static const serviceFee = 'SERVICE_FEE';
  static const discount = 'DISCOUNT';
}

class PricingServiceFee {
  const PricingServiceFee({
    required this.serviceCode,
    required this.displayName,
    required this.amount,
    required this.isEnabled,
    required this.updatedAt,
  });

  final String serviceCode;
  final String displayName;
  final double amount;
  final bool isEnabled;
  final DateTime updatedAt;

  PricingServiceFee copyWith({
    String? serviceCode,
    String? displayName,
    double? amount,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return PricingServiceFee(
      serviceCode: serviceCode ?? this.serviceCode,
      displayName: displayName ?? this.displayName,
      amount: amount ?? this.amount,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PricingCampaign {
  const PricingCampaign({
    required this.id,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.appliesToService,
    required this.minOrderAmount,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final String discountType;
  final double discountValue;
  final String? appliesToService;
  final double minOrderAmount;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PricingCampaign copyWith({
    int? id,
    String? name,
    Object? description = _sentinel,
    String? discountType,
    double? discountValue,
    Object? appliesToService = _sentinel,
    double? minOrderAmount,
    bool? isActive,
    Object? startsAt = _sentinel,
    Object? endsAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PricingCampaign(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      appliesToService: identical(appliesToService, _sentinel)
          ? this.appliesToService
          : appliesToService as String?,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      isActive: isActive ?? this.isActive,
      startsAt: identical(startsAt, _sentinel)
          ? this.startsAt
          : startsAt as DateTime?,
      endsAt:
          identical(endsAt, _sentinel) ? this.endsAt : endsAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PricingQuoteLine {
  const PricingQuoteLine({
    required this.label,
    required this.type,
    required this.amount,
  });

  final String label;
  final String type;
  final double amount;
}

class PricingQuote {
  const PricingQuote({
    required this.machineSubtotal,
    required this.serviceFeeTotal,
    required this.discountTotal,
    required this.finalTotal,
    required this.appliedCampaigns,
    required this.lines,
  });

  final double machineSubtotal;
  final double serviceFeeTotal;
  final double discountTotal;
  final double finalTotal;
  final List<PricingCampaign> appliedCampaigns;
  final List<PricingQuoteLine> lines;
}

const _sentinel = Object();