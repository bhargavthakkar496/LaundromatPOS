export function serializeUser(row: {
  id: number;
  username: string;
  display_name: string;
  role: string;
}) {
  return {
    id: Number(row.id),
    username: row.username,
    displayName: row.display_name,
    role: row.role,
  };
}

export function serializeMachine(row: {
  id: number;
  name: string;
  type: string;
  capacity_kg: number;
  price: number | string;
  status: string;
  current_order_id: number | null;
  cycle_started_at: Date | string | null;
  cycle_ends_at: Date | string | null;
}) {
  return {
    id: Number(row.id),
    name: row.name,
    type: row.type,
    capacityKg: row.capacity_kg,
    price: Number(row.price),
    status: row.status,
    currentOrderId:
      row.current_order_id == null ? null : Number(row.current_order_id),
    cycleStartedAt: row.cycle_started_at
      ? new Date(row.cycle_started_at).toISOString()
      : null,
    cycleEndsAt: row.cycle_ends_at
      ? new Date(row.cycle_ends_at).toISOString()
      : null,
  };
}

export function serializeCustomer(row: {
  id: number;
  full_name: string;
  phone: string;
  preferred_washer_size_kg: number | null;
  preferred_detergent_add_on: string | null;
  preferred_dryer_duration_minutes: number | null;
}) {
  return {
    id: Number(row.id),
    fullName: row.full_name,
    phone: row.phone,
    preferredWasherSizeKg: row.preferred_washer_size_kg,
    preferredDetergentAddOn: row.preferred_detergent_add_on,
    preferredDryerDurationMinutes: row.preferred_dryer_duration_minutes,
  };
}

export function serializeOrder(row: {
  id: number;
  machine_id: number;
  customer_id: number;
  created_by_user_id: number | null;
  service_type: string;
  selected_services: string[] | null;
  amount: number | string;
  status: string;
  payment_method: string;
  payment_status: string;
  payment_reference: string;
  timestamp: Date | string;
  load_size_kg: number | null;
  wash_option: string | null;
  dryer_machine_id: number | null;
  ironing_machine_id: number | null;
}) {
  return {
    id: Number(row.id),
    machineId: Number(row.machine_id),
    customerId: Number(row.customer_id),
    createdByUserId:
      row.created_by_user_id == null ? null : Number(row.created_by_user_id),
    serviceType: row.service_type,
    selectedServices: row.selected_services ?? [],
    amount: Number(row.amount),
    status: row.status,
    paymentMethod: row.payment_method,
    paymentStatus: row.payment_status,
    paymentReference: row.payment_reference,
    timestamp: new Date(row.timestamp).toISOString(),
    loadSizeKg: row.load_size_kg,
    washOption: row.wash_option,
    dryerMachineId:
      row.dryer_machine_id == null ? null : Number(row.dryer_machine_id),
    ironingMachineId:
      row.ironing_machine_id == null ? null : Number(row.ironing_machine_id),
  };
}

export function serializeReservation(row: {
  id: number;
  machine_id: number;
  customer_id: number;
  start_time: Date | string;
  end_time: Date | string;
  status: string;
  created_at: Date | string;
  preferred_washer_size_kg: number | null;
  detergent_add_on: string | null;
  dryer_duration_minutes: number | null;
}) {
  return {
    id: Number(row.id),
    machineId: Number(row.machine_id),
    customerId: Number(row.customer_id),
    startTime: new Date(row.start_time).toISOString(),
    endTime: new Date(row.end_time).toISOString(),
    status: row.status,
    createdAt: new Date(row.created_at).toISOString(),
    preferredWasherSizeKg: row.preferred_washer_size_kg,
    detergentAddOn: row.detergent_add_on,
    dryerDurationMinutes: row.dryer_duration_minutes,
  };
}

export function serializeRefundRequest(row: {
  id: number;
  order_id: number;
  customer_full_name: string;
  customer_phone: string;
  machine_name: string;
  amount: number | string;
  payment_method: string;
  payment_reference: string;
  reason: string;
  status: string;
  requested_at: Date | string;
  requested_by_name: string | null;
  processed_at: Date | string | null;
  processed_by_name: string | null;
}) {
  return {
    id: Number(row.id),
    orderId: Number(row.order_id),
    customerName: row.customer_full_name,
    customerPhone: row.customer_phone,
    machineName: row.machine_name,
    amount: Number(row.amount),
    paymentMethod: row.payment_method,
    paymentReference: row.payment_reference,
    reason: row.reason,
    status: row.status,
    requestedAt: new Date(row.requested_at).toISOString(),
    requestedByName: row.requested_by_name,
    processedAt: row.processed_at
      ? new Date(row.processed_at).toISOString()
      : null,
    processedByName: row.processed_by_name,
  };
}

export function serializePricingServiceFee(row: {
  service_code: string;
  display_name: string;
  amount: number | string;
  is_enabled: boolean;
  updated_at: Date | string;
}) {
  return {
    serviceCode: row.service_code,
    displayName: row.display_name,
    amount: Number(row.amount),
    isEnabled: row.is_enabled,
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

export function serializePricingCampaign(row: {
  id: number;
  name: string;
  description: string | null;
  discount_type: string;
  discount_value: number | string;
  applies_to_service: string | null;
  min_order_amount: number | string;
  is_active: boolean;
  starts_at: Date | string | null;
  ends_at: Date | string | null;
  created_at: Date | string;
  updated_at: Date | string;
}) {
  return {
    id: Number(row.id),
    name: row.name,
    description: row.description,
    discountType: row.discount_type,
    discountValue: Number(row.discount_value),
    appliesToService: row.applies_to_service,
    minOrderAmount: Number(row.min_order_amount),
    isActive: row.is_active,
    startsAt: row.starts_at ? new Date(row.starts_at).toISOString() : null,
    endsAt: row.ends_at ? new Date(row.ends_at).toISOString() : null,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

export function serializePricingQuote(input: {
  machineSubtotal: number;
  serviceFeeTotal: number;
  discountTotal: number;
  finalTotal: number;
  appliedCampaigns: Array<{
    id: number;
    name: string;
    description: string | null;
    discount_type: string;
    discount_value: number | string;
    applies_to_service: string | null;
    min_order_amount: number | string;
    is_active: boolean;
    starts_at: Date | string | null;
    ends_at: Date | string | null;
    created_at: Date | string;
    updated_at: Date | string;
  }>;
  lines: Array<{
    label: string;
    type: 'MACHINE' | 'SERVICE_FEE' | 'DISCOUNT';
    amount: number;
  }>;
}) {
  return {
    machineSubtotal: input.machineSubtotal,
    serviceFeeTotal: input.serviceFeeTotal,
    discountTotal: input.discountTotal,
    finalTotal: input.finalTotal,
    appliedCampaigns: input.appliedCampaigns.map((item) =>
      serializePricingCampaign(item),
    ),
    lines: input.lines,
  };
}

export function serializeMaintenanceRecord(row: {
  id: number;
  machine_id: number;
  issue_title: string;
  issue_description: string | null;
  priority: string;
  status: string;
  reported_by_name: string | null;
  started_by_name: string | null;
  completed_by_name: string | null;
  reported_at: Date | string;
  started_at: Date | string | null;
  completed_at: Date | string | null;
  resolution_notes: string | null;
  created_at: Date | string;
  updated_at: Date | string;
}) {
  return {
    id: Number(row.id),
    machineId: Number(row.machine_id),
    issueTitle: row.issue_title,
    issueDescription: row.issue_description,
    priority: row.priority,
    status: row.status,
    reportedByName: row.reported_by_name,
    startedByName: row.started_by_name,
    completedByName: row.completed_by_name,
    reportedAt: new Date(row.reported_at).toISOString(),
    startedAt: row.started_at ? new Date(row.started_at).toISOString() : null,
    completedAt: row.completed_at
      ? new Date(row.completed_at).toISOString()
      : null,
    resolutionNotes: row.resolution_notes,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

export function serializePaymentSession(row: {
  id: number;
  amount: number | string;
  payment_method: string;
  reference: string;
  qr_payload: string;
  status: string;
  attempt: number;
  created_at: Date | string;
  checked_at: Date | string;
  failure_reason: string | null;
}) {
  return {
    id: Number(row.id),
    amount: Number(row.amount),
    paymentMethod: row.payment_method,
    reference: row.reference,
    qrPayload: row.qr_payload,
    status: row.status,
    attempt: Number(row.attempt),
    createdAt: new Date(row.created_at).toISOString(),
    checkedAt: new Date(row.checked_at).toISOString(),
    failureReason: row.failure_reason,
  };
}

export function serializeActiveOrderSession(row: {
  customer_name: string;
  customer_phone: string;
  load_size_kg: number;
  selected_services: string[] | null;
  wash_option: string | null;
  washer_machine_id: number | null;
  dryer_machine_id: number | null;
  ironing_machine_id: number | null;
  payment_method: string;
  stage: string;
  created_at: Date | string;
  confirmed_by: string | null;
  order_id: number | null;
  payment_reference: string | null;
}) {
  return {
    customerName: row.customer_name,
    customerPhone: row.customer_phone,
    loadSizeKg: row.load_size_kg,
    selectedServices: row.selected_services ?? [],
    washOption: row.wash_option,
    washerMachineId:
      row.washer_machine_id == null ? null : Number(row.washer_machine_id),
    dryerMachineId:
      row.dryer_machine_id == null ? null : Number(row.dryer_machine_id),
    ironingMachineId:
      row.ironing_machine_id == null ? null : Number(row.ironing_machine_id),
    paymentMethod: row.payment_method,
    stage: row.stage,
    createdAt: new Date(row.created_at).toISOString(),
    confirmedBy: row.confirmed_by,
    orderId: row.order_id == null ? null : Number(row.order_id),
    paymentReference: row.payment_reference,
  };
}

export function serializeInventoryCategorySummary(row: {
  category: string;
  item_count: number | string;
  low_stock_count: number | string;
  out_of_stock_count: number | string;
}) {
  return {
    category: row.category,
    itemCount: Number(row.item_count),
    lowStockCount: Number(row.low_stock_count),
    outOfStockCount: Number(row.out_of_stock_count),
  };
}

export function serializeInventoryDashboard(row: {
  low_stock_count: number | string;
  out_of_stock_count: number | string;
  stock_value: number | string | null;
  pending_purchase_orders: number | string;
  expiring_soon_count: number | string;
}) {
  return {
    lowStockCount: Number(row.low_stock_count),
    outOfStockCount: Number(row.out_of_stock_count),
    stockValue: Number(row.stock_value ?? 0),
    pendingPurchaseOrders: Number(row.pending_purchase_orders),
    expiringSoonCount: Number(row.expiring_soon_count),
  };
}

export function serializeInventoryItem(row: {
  id: number;
  sku: string;
  barcode: string | null;
  name: string;
  category: string;
  supplier_name: string | null;
  branch_name: string;
  location_name: string;
  unit: string;
  unit_type: string;
  pack_size: string | null;
  quantity_on_hand: number | string;
  reorder_point: number | string;
  par_level: number | string;
  unit_cost: number | string;
  selling_price: number | string | null;
  stock_value: number | string;
  last_restocked_at: Date | string | null;
  expires_at: Date | string | null;
  stock_status: string;
  is_active: boolean;
  reorder_urgency_score: number | string;
  active_restock_request_id: number | null;
  active_restock_request_status: string | null;
  active_restock_request_number: string | null;
  active_restock_requested_quantity: number | string | null;
  active_restock_operator_remarks: string | null;
  active_restock_approved_at: Date | string | null;
}) {
  return {
    id: Number(row.id),
    sku: row.sku,
    barcode: row.barcode,
    name: row.name,
    category: row.category,
    supplier: row.supplier_name,
    branch: row.branch_name,
    location: row.location_name,
    unit: row.unit,
    unitType: row.unit_type,
    packSize: row.pack_size,
    quantityOnHand: Number(row.quantity_on_hand),
    reorderPoint: Number(row.reorder_point),
    parLevel: Number(row.par_level),
    unitCost: Number(row.unit_cost),
    sellingPrice:
      row.selling_price == null ? null : Number(row.selling_price),
    stockValue: Number(row.stock_value),
    lastRestockedAt: row.last_restocked_at
      ? new Date(row.last_restocked_at).toISOString()
      : null,
    expiresAt: row.expires_at ? new Date(row.expires_at).toISOString() : null,
    stockStatus: row.stock_status,
    isActive: row.is_active,
    reorderUrgencyScore: Number(row.reorder_urgency_score),
    activeRestockRequestId:
      row.active_restock_request_id == null
        ? null
        : Number(row.active_restock_request_id),
    activeRestockRequestStatus: row.active_restock_request_status,
    activeRestockRequestNumber: row.active_restock_request_number,
    activeRestockRequestedQuantity:
      row.active_restock_requested_quantity == null
        ? null
        : Number(row.active_restock_requested_quantity),
    activeRestockOperatorRemarks: row.active_restock_operator_remarks,
    activeRestockApprovedAt: row.active_restock_approved_at
      ? new Date(row.active_restock_approved_at).toISOString()
      : null,
  };
}

export function serializeInventoryStockMovement(row: {
  id: number;
  inventory_item_id: number;
  movement_type: string;
  quantity_delta: number | string;
  balance_after: number | string;
  reference_type: string | null;
  reference_id: string | null;
  notes: string | null;
  performed_by_name: string | null;
  occurred_at: Date | string;
}) {
  return {
    id: Number(row.id),
    inventoryItemId: Number(row.inventory_item_id),
    movementType: row.movement_type,
    quantityDelta: Number(row.quantity_delta),
    balanceAfter: Number(row.balance_after),
    referenceType: row.reference_type,
    referenceId: row.reference_id,
    notes: row.notes,
    performedByName: row.performed_by_name,
    occurredAt: new Date(row.occurred_at).toISOString(),
  };
}

export function serializeInventoryRestockRequest(row: {
  id: number;
  request_number: string;
  inventory_item_id: number;
  item_name: string;
  item_sku: string;
  item_category: string;
  supplier_name: string | null;
  branch_name: string;
  location_name: string;
  unit: string;
  requested_quantity: number | string;
  status: string;
  request_notes: string | null;
  operator_remarks: string | null;
  requested_by_name: string | null;
  approved_by_name: string | null;
  created_at: Date | string;
  approved_at: Date | string | null;
}) {
  return {
    id: Number(row.id),
    requestNumber: row.request_number,
    inventoryItemId: Number(row.inventory_item_id),
    itemName: row.item_name,
    itemSku: row.item_sku,
    itemCategory: row.item_category,
    supplier: row.supplier_name,
    branch: row.branch_name,
    location: row.location_name,
    unit: row.unit,
    requestedQuantity: Number(row.requested_quantity),
    status: row.status,
    requestNotes: row.request_notes,
    operatorRemarks: row.operator_remarks,
    requestedByName: row.requested_by_name,
    approvedByName: row.approved_by_name,
    createdAt: new Date(row.created_at).toISOString(),
    approvedAt: row.approved_at
      ? new Date(row.approved_at).toISOString()
      : null,
  };
}
