export type UserRole =
  | "ADMIN"
  | "MANAGER"
  | "CASHIER"
  | "TECHNICIAN"
  | "SUPPORT";

export type MachineStatus =
  | "AVAILABLE"
  | "MAINTENANCE"
  | "IN_USE"
  | "READY_FOR_PICKUP";

export type OrderStatus = "BOOKED" | "IN_PROGRESS" | "COMPLETED" | "CANCELLED";

export type PaymentStatus = "PENDING" | "PAID" | "FAILED" | "REFUNDED";
export type RefundRequestStatus = "PENDING" | "PROCESSED";
export type PricingDiscountType = "PERCENT" | "FIXED";
export type MaintenancePriority = "LOW" | "MEDIUM" | "HIGH";
export type MaintenanceStatus = "MARKED" | "IN_PROGRESS" | "COMPLETED";
export type PaymentSessionStatus =
  | "AWAITING_SCAN"
  | "PROCESSING"
  | "PAID"
  | "FAILED";
export type ReservationStatus = "BOOKED" | "FULFILLED" | "CANCELLED";
export type ActiveOrderSessionStage = "DRAFT" | "BOOKED" | "PAID";
export type InventoryStockStatus =
  | "HEALTHY"
  | "LOW"
  | "OUT_OF_STOCK"
  | "IN_PROCUREMENT";
export type InventoryRestockRequestStatus =
  | "PENDING"
  | "APPROVED"
  | "PROCURED";
export type InventoryMovementType =
  | "RECEIVED"
  | "CONSUMED"
  | "TRANSFERRED"
  | "DAMAGED"
  | "RETURNED"
  | "MANUAL_CORRECTION";

export interface PosUserDto {
  id: number;
  username: string;
  displayName: string;
  pin?: string;
  role: UserRole;
}

export interface AuthSessionDto {
  accessToken: string;
  refreshToken?: string | null;
  expiresAt?: string | null;
  user: PosUserDto;
}

export interface InventoryCategorySummaryDto {
  category: string;
  itemCount: number;
  lowStockCount: number;
  outOfStockCount: number;
}

export interface InventoryDashboardMetricsDto {
  lowStockCount: number;
  outOfStockCount: number;
  stockValue: number;
  pendingPurchaseOrders: number;
  expiringSoonCount: number;
}

export interface InventoryDashboardDto {
  metrics: InventoryDashboardMetricsDto;
  categories: InventoryCategorySummaryDto[];
  suppliers: string[];
  branches: string[];
  locations: string[];
}

export interface InventoryItemDto {
  id: number;
  sku: string;
  barcode: string | null;
  name: string;
  category: string;
  supplier: string | null;
  branch: string;
  location: string;
  unit: string;
  unitType: string;
  packSize: string | null;
  quantityOnHand: number;
  reorderPoint: number;
  parLevel: number;
  unitCost: number;
  sellingPrice: number | null;
  stockValue: number;
  lastRestockedAt: string | null;
  expiresAt: string | null;
  stockStatus: InventoryStockStatus;
  isActive: boolean;
  reorderUrgencyScore: number;
  activeRestockRequestId: number | null;
  activeRestockRequestStatus: InventoryRestockRequestStatus | null;
  activeRestockRequestNumber: string | null;
  activeRestockRequestedQuantity: number | null;
  activeRestockOperatorRemarks: string | null;
  activeRestockApprovedAt: string | null;
}

export interface InventoryStockMovementDto {
  id: number;
  inventoryItemId: number;
  movementType: InventoryMovementType;
  quantityDelta: number;
  balanceAfter: number;
  referenceType: string | null;
  referenceId: string | null;
  notes: string | null;
  performedByName: string | null;
  occurredAt: string;
}

export interface RefundRequestDto {
  id: number;
  orderId: number;
  customerName: string;
  customerPhone: string;
  machineName: string;
  amount: number;
  paymentMethod: string;
  paymentReference: string;
  reason: string;
  status: RefundRequestStatus;
  requestedAt: string;
  requestedByName: string | null;
  processedAt: string | null;
  processedByName: string | null;
}

export interface PricingServiceFeeDto {
  serviceCode: string;
  displayName: string;
  amount: number;
  isEnabled: boolean;
  updatedAt: string;
}

export interface PricingCampaignDto {
  id: number;
  name: string;
  description: string | null;
  discountType: PricingDiscountType;
  discountValue: number;
  appliesToService: string | null;
  minOrderAmount: number;
  isActive: boolean;
  startsAt: string | null;
  endsAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PricingQuoteLineDto {
  label: string;
  type: "MACHINE" | "SERVICE_FEE" | "DISCOUNT";
  amount: number;
}

export interface PricingQuoteDto {
  machineSubtotal: number;
  serviceFeeTotal: number;
  discountTotal: number;
  finalTotal: number;
  appliedCampaigns: PricingCampaignDto[];
  lines: PricingQuoteLineDto[];
}

export interface MaintenanceRecordDto {
  id: number;
  machineId: number;
  issueTitle: string;
  issueDescription: string | null;
  priority: MaintenancePriority;
  status: MaintenanceStatus;
  reportedByName: string | null;
  startedByName: string | null;
  completedByName: string | null;
  reportedAt: string;
  startedAt: string | null;
  completedAt: string | null;
  resolutionNotes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InventoryRestockRequestDto {
  id: number;
  requestNumber: string;
  inventoryItemId: number;
  itemName: string;
  itemSku: string;
  itemCategory: string;
  supplier: string | null;
  branch: string;
  location: string;
  unit: string;
  requestedQuantity: number;
  status: InventoryRestockRequestStatus;
  requestNotes: string | null;
  operatorRemarks: string | null;
  requestedByName: string | null;
  approvedByName: string | null;
  createdAt: string;
  approvedAt: string | null;
}
