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
