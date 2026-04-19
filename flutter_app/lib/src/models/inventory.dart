class InventoryStockStatus {
  static const healthy = 'HEALTHY';
  static const low = 'LOW';
  static const outOfStock = 'OUT_OF_STOCK';
  static const inProcurement = 'IN_PROCUREMENT';
}

class InventoryRestockRequestStatus {
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const procured = 'PROCURED';
}

class InventoryDashboardMetrics {
  const InventoryDashboardMetrics({
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockValue,
    required this.pendingPurchaseOrders,
    required this.expiringSoonCount,
  });

  final int lowStockCount;
  final int outOfStockCount;
  final double stockValue;
  final int pendingPurchaseOrders;
  final int expiringSoonCount;
}

class InventoryCategorySummary {
  const InventoryCategorySummary({
    required this.category,
    required this.itemCount,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  final String category;
  final int itemCount;
  final int lowStockCount;
  final int outOfStockCount;
}

class InventoryDashboard {
  const InventoryDashboard({
    required this.metrics,
    required this.categories,
    required this.suppliers,
    required this.branches,
    required this.locations,
  });

  final InventoryDashboardMetrics metrics;
  final List<InventoryCategorySummary> categories;
  final List<String> suppliers;
  final List<String> branches;
  final List<String> locations;
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.category,
    required this.supplier,
    required this.branch,
    required this.location,
    required this.unit,
    required this.unitType,
    required this.packSize,
    required this.quantityOnHand,
    required this.reorderPoint,
    required this.parLevel,
    required this.unitCost,
    required this.sellingPrice,
    required this.stockValue,
    required this.lastRestockedAt,
    required this.expiresAt,
    required this.stockStatus,
    required this.isActive,
    required this.reorderUrgencyScore,
    required this.activeRestockRequestId,
    required this.activeRestockRequestStatus,
    required this.activeRestockRequestNumber,
    required this.activeRestockRequestedQuantity,
    required this.activeRestockOperatorRemarks,
    required this.activeRestockApprovedAt,
  });

  final int id;
  final String sku;
  final String? barcode;
  final String name;
  final String category;
  final String? supplier;
  final String branch;
  final String location;
  final String unit;
  final String unitType;
  final String? packSize;
  final int quantityOnHand;
  final int reorderPoint;
  final int parLevel;
  final double unitCost;
  final double? sellingPrice;
  final double stockValue;
  final DateTime? lastRestockedAt;
  final DateTime? expiresAt;
  final String stockStatus;
  final bool isActive;
  final int reorderUrgencyScore;
  final int? activeRestockRequestId;
  final String? activeRestockRequestStatus;
  final String? activeRestockRequestNumber;
  final int? activeRestockRequestedQuantity;
  final String? activeRestockOperatorRemarks;
  final DateTime? activeRestockApprovedAt;
}

class InventoryStockMovementType {
  static const received = 'RECEIVED';
  static const consumed = 'CONSUMED';
  static const transferred = 'TRANSFERRED';
  static const damaged = 'DAMAGED';
  static const returned = 'RETURNED';
  static const manualCorrection = 'MANUAL_CORRECTION';
}

class InventoryStockMovement {
  const InventoryStockMovement({
    required this.id,
    required this.inventoryItemId,
    required this.movementType,
    required this.quantityDelta,
    required this.balanceAfter,
    required this.referenceType,
    required this.referenceId,
    required this.notes,
    required this.performedByName,
    required this.occurredAt,
  });

  final int id;
  final int inventoryItemId;
  final String movementType;
  final int quantityDelta;
  final int balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final String? performedByName;
  final DateTime occurredAt;
}

class InventoryRestockRequest {
  const InventoryRestockRequest({
    required this.id,
    required this.requestNumber,
    required this.inventoryItemId,
    required this.itemName,
    required this.itemSku,
    required this.itemCategory,
    required this.supplier,
    required this.branch,
    required this.location,
    required this.unit,
    required this.requestedQuantity,
    required this.status,
    required this.requestNotes,
    required this.operatorRemarks,
    required this.requestedByName,
    required this.approvedByName,
    required this.createdAt,
    required this.approvedAt,
  });

  final int id;
  final String requestNumber;
  final int inventoryItemId;
  final String itemName;
  final String itemSku;
  final String itemCategory;
  final String? supplier;
  final String branch;
  final String location;
  final String unit;
  final int requestedQuantity;
  final String status;
  final String? requestNotes;
  final String? operatorRemarks;
  final String? requestedByName;
  final String? approvedByName;
  final DateTime createdAt;
  final DateTime? approvedAt;
}
