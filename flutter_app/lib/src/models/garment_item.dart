class GarmentItemStatus {
  static const received = 'RECEIVED';
  static const tagPending = 'TAG_PENDING';
  static const tagged = 'TAGGED';
  static const washingPending = 'WASHING_PENDING';
  static const washing = 'WASHING';
  static const dryingPending = 'DRYING_PENDING';
  static const drying = 'DRYING';
  static const ironingPending = 'IRONING_PENDING';
  static const ironing = 'IRONING';
  static const readyForPickup = 'READY_FOR_PICKUP';
  static const delivered = 'DELIVERED';
}

class GarmentItem {
  const GarmentItem({
    required this.tagId,
    required this.garmentLabel,
    required this.quantity,
    required this.selectedServices,
    required this.unitPrice,
    required this.status,
    required this.sourceDeduplicationKey,
  });

  final String tagId;
  final String garmentLabel;
  final int quantity;
  final List<String> selectedServices;
  final double unitPrice;
  final String status;
  final String sourceDeduplicationKey;

  double get lineTotal => unitPrice * quantity;

  GarmentItem copyWith({
    String? tagId,
    String? garmentLabel,
    int? quantity,
    List<String>? selectedServices,
    double? unitPrice,
    String? status,
    String? sourceDeduplicationKey,
  }) {
    return GarmentItem(
      tagId: tagId ?? this.tagId,
      garmentLabel: garmentLabel ?? this.garmentLabel,
      quantity: quantity ?? this.quantity,
      selectedServices: selectedServices ?? this.selectedServices,
      unitPrice: unitPrice ?? this.unitPrice,
      status: status ?? this.status,
      sourceDeduplicationKey:
          sourceDeduplicationKey ?? this.sourceDeduplicationKey,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'tagId': tagId,
      'garmentLabel': garmentLabel,
      'quantity': quantity,
      'selectedServices': selectedServices,
      'unitPrice': unitPrice,
      'status': status,
      'sourceDeduplicationKey': sourceDeduplicationKey,
    };
  }

  factory GarmentItem.fromJson(Map<String, dynamic> json) {
    return GarmentItem(
      tagId: json['tagId'] as String? ?? '',
      garmentLabel: json['garmentLabel'] as String? ?? 'Tagged Garment',
      quantity: json['quantity'] as int? ?? 1,
      selectedServices: (json['selectedServices'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? GarmentItemStatus.received,
      sourceDeduplicationKey:
          json['sourceDeduplicationKey'] as String? ??
              (json['tagId'] as String? ?? ''),
    );
  }
}
