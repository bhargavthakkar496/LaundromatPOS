# Backend Implementation Plan

This plan maps the current API contract in `backend/api/openapi.yaml` to PostgreSQL tables, transaction boundaries, and audit logging expectations.

## Conventions

- Write operations should use a database transaction.
- Read-only endpoints generally do not need a transaction unless they combine multiple consistency-sensitive reads.
- Every state-changing endpoint should write an `audit_logs` row.
- Device-originated machine transitions should also write `machine_events`.
- `entity_type` values in `audit_logs` should be stable strings such as `user`, `customer`, `machine`, `order`, `payment_session`, `active_order_session`, `reservation`.

## Auth

### `POST /auth/login`

- Tables:
  - `users`
  - `auth_sessions`
  - optional `devices`
- Flow:
  1. Look up active user by `username`.
  2. Verify submitted PIN against `pin_hash`.
  3. Create `auth_sessions` row with hashed access token and optional refresh token.
  4. Return `AuthSession`.
- Transaction:
  - Yes.
- Audit write:
  - `action = auth.login`
  - `entity_type = user`
  - `entity_id = {user.id}`
  - `after_state` may include session id and issued expiry metadata.

## Machines

### `GET /machines`

- Tables:
  - `machines`
- Flow:
  1. Filter by `status` when provided.
  2. Return current machine state including `current_order_id`, `cycle_started_at`, `cycle_ends_at`.
- Transaction:
  - No.
- Audit write:
  - None.

### `GET /machines/{machineId}`

- Tables:
  - `machines`
- Flow:
  1. Load machine by id.
  2. Return 404 if missing.
- Transaction:
  - No.
- Audit write:
  - None.

### `GET /machines/reservable`

- Tables:
  - `machines`
  - `machine_reservations`
- Flow:
  1. Select machines matching type and not in maintenance.
  2. Exclude in-use machines whose `cycle_ends_at` overlaps requested window.
  3. Exclude machines with overlapping `machine_reservations` in `BOOKED`.
- Transaction:
  - No.
- Audit write:
  - None.

### `POST /machines/{machineId}/pickup`

- Tables:
  - `machines`
  - `orders`
  - `audit_logs`
- Flow:
  1. Load machine by id.
  2. Clear `current_order_id`, `cycle_started_at`, `cycle_ends_at`.
  3. Set `status = AVAILABLE`.
  4. If desired, optionally update the linked order to `COMPLETED` when pickup is the completion boundary.
- Transaction:
  - Yes.
- Audit write:
  - `action = machine.pickup`
  - `entity_type = machine`
  - `entity_id = {machineId}`
  - `before_state` = previous machine record
  - `after_state` = updated machine record

## Customers

### `GET /customers/by-phone`

- Tables:
  - `customers`
- Flow:
  1. Find customer by normalized phone.
  2. Return 404 if missing.
- Transaction:
  - No.
- Audit write:
  - None.

### `POST /customers/walk-in`

- Tables:
  - `customers`
  - `audit_logs`
- Flow:
  1. Find customer by phone.
  2. If found, update name/preferences.
  3. If missing, insert new customer.
  4. Return saved customer.
- Transaction:
  - Yes.
- Audit write:
  - `action = customer.upsert_walk_in`
  - `entity_type = customer`
  - `entity_id = {customer.id}`
  - Include before/after states for updates.

### `GET /customers/profile`

- Tables:
  - `customers`
  - `orders`
  - `machines`
  - `machine_reservations`
- Flow:
  1. Find customer by phone.
  2. Load customer orders joined to machines.
  3. Compute `totalSpent` from paid/refunded policy you choose.
  4. Compute `totalVisits`.
  5. Aggregate favorite machines from order counts.
  6. Load future booked reservations.
  7. Return composed profile DTO.
- Transaction:
  - No.
- Audit write:
  - None.

## Orders

### `GET /orders/history`

- Tables:
  - `orders`
  - `customers`
  - `machines`
- Flow:
  1. Query orders ordered by timestamp descending.
  2. Join `customers`, primary `machines`, and optional dryer machine.
  3. Return `OrderHistoryItem[]`.
- Transaction:
  - No.
- Audit write:
  - None.

### `GET /orders/{orderId}/history-item`

- Tables:
  - `orders`
  - `customers`
  - `machines`
- Flow:
  1. Query a single order and its joined entities.
  2. Return 404 if missing.
- Transaction:
  - No.
- Audit write:
  - None.

### `POST /orders/paid`

- Tables:
  - `orders`
  - `payments`
  - `machines`
  - `audit_logs`
  - optional `machine_events`
- Flow:
  1. Validate machine availability and customer existence.
  2. Insert order with `status = IN_PROGRESS`, `payment_status = PAID`.
  3. Insert payment row.
  4. Update machine to `IN_USE`, set `current_order_id`, cycle timestamps.
  5. Optionally append `machine_events` lifecycle event.
- Transaction:
  - Yes.
- Audit write:
  - `action = order.create_paid`
  - `entity_type = order`
  - `entity_id = {order.id}`
  - Include linked payment and machine assignment metadata.

### `POST /orders/manual`

- Tables:
  - `customers`
  - `orders`
  - `machines`
  - `audit_logs`
- Flow:
  1. Upsert customer by phone.
  2. Insert order with requested `orderStatus`.
  3. If status is `IN_PROGRESS`, update washer machine assignment and cycle timestamps.
  4. If status is `BOOKED`, leave machine available or reserve behavior based on business rules.
- Transaction:
  - Yes.
- Audit write:
  - `action = order.create_manual`
  - `entity_type = order`
  - `entity_id = {order.id}`

### `POST /orders/{orderId}/refund`

- Tables:
  - `orders`
  - `payments`
  - `audit_logs`
- Flow:
  1. Load target order.
  2. Update order `payment_status = REFUNDED`.
  3. Update related payment rows as refunded if tracked one-to-many.
  4. Return updated order.
- Transaction:
  - Yes.
- Audit write:
  - `action = order.refund_processed`
  - `entity_type = order`
  - `entity_id = {orderId}`
  - `before_state` = original order
  - `after_state` = refunded order

## Payments

### `POST /payments/sessions`

- Tables:
  - `payment_sessions`
  - `audit_logs`
- Flow:
  1. Generate payment reference.
  2. Generate QR payload.
  3. Insert `payment_sessions` row in `AWAITING_SCAN`.
  4. Return payment session DTO.
- Transaction:
  - Yes.
- Audit write:
  - `action = payment_session.create`
  - `entity_type = payment_session`
  - `entity_id = {session.id}`

### `GET /payments/sessions/{sessionId}`

- Tables:
  - `payment_sessions`
- Flow:
  1. Load session.
  2. Optionally advance session based on PSP callback state or polling adapter.
  3. Update `checked_at`.
  4. Return current state.
- Transaction:
  - Yes if `checked_at` or status is updated; otherwise no.
- Audit write:
  - Optional if status changes:
    - `action = payment_session.status_changed`

## Reservations

### `POST /reservations`

- Tables:
  - `machine_reservations`
  - `machines`
  - `customers`
  - `audit_logs`
- Flow:
  1. Validate machine and customer.
  2. Validate no overlap with in-use window and active reservations.
  3. Insert reservation row with `BOOKED`.
  4. Return reservation DTO.
- Transaction:
  - Yes.
- Audit write:
  - `action = reservation.create`
  - `entity_type = reservation`
  - `entity_id = {reservation.id}`

## Active Order Session

### `GET /active-order-session`

- Tables:
  - `active_order_sessions`
- Flow:
  1. Return the single row where `is_active = TRUE`.
  2. Return 404 if missing.
- Transaction:
  - No.
- Audit write:
  - None.

### `DELETE /active-order-session`

- Tables:
  - `active_order_sessions`
  - `audit_logs`
- Flow:
  1. Mark current active session inactive.
  2. Keep historical row for traceability.
- Transaction:
  - Yes.
- Audit write:
  - `action = active_order_session.clear`
  - `entity_type = active_order_session`
  - `entity_id = {session.id}`

### `POST /active-order-session/draft`

- Tables:
  - `active_order_sessions`
  - `audit_logs`
- Flow:
  1. Inactivate any existing active session.
  2. Insert new session row with `stage = DRAFT`.
  3. Return created session.
- Transaction:
  - Yes.
- Audit write:
  - `action = active_order_session.save_draft`
  - `entity_type = active_order_session`
  - `entity_id = {session.id}`

### `POST /active-order-session/confirm`

- Tables:
  - `active_order_sessions`
  - `orders`
  - `customers`
  - `audit_logs`
- Flow:
  1. Load active session.
  2. Upsert customer by session phone.
  3. Insert `orders` row with `status = BOOKED`, `payment_status = PENDING`.
  4. Update active session to `stage = BOOKED`, attach `order_id`, `confirmed_by`.
  5. Return updated session.
- Transaction:
  - Yes.
- Audit write:
  - `action = active_order_session.confirm`
  - `entity_type = active_order_session`
  - `entity_id = {session.id}`
  - Optionally also `action = order.create_booked`

### `POST /active-order-session/payment`

- Tables:
  - `active_order_sessions`
  - `orders`
  - `payments`
  - `machines`
  - `machine_events`
  - `audit_logs`
- Flow:
  1. Load active session and linked order.
  2. Update order to `status = IN_PROGRESS`, `payment_status = PAID`, set `payment_reference`.
  3. Insert payment row.
  4. Update washer machine to `IN_USE`, set `current_order_id`, cycle timestamps.
  5. Update active session to `stage = PAID`, set `payment_reference`.
  6. Insert `machine_events` lifecycle row.
- Transaction:
  - Yes.
- Audit write:
  - `action = active_order_session.payment_completed`
  - `entity_type = active_order_session`
  - `entity_id = {session.id}`
  - Also record linked order/payment/machine metadata in `after_state` or `metadata`.

## Machine Telemetry and Device Event Writes

These are not directly covered by the current Flutter REST repository, but should be first-class backend operations:

- Source tables:
  - `devices`
  - `machines`
  - `machine_events`
  - `audit_logs`
- Recommended backend behavior:
  1. Accept normalized device event.
  2. Validate device identity.
  3. Insert `machine_events` row.
  4. Update `machines` current status snapshot.
  5. Write `audit_logs` with `actor_type = DEVICE`.

## Audit Log Shape

Recommended minimum fields for every audit write:

- `actor_type`
- `actor_user_id` or `actor_device_id`
- `action`
- `entity_type`
- `entity_id`
- `request_id`
- `before_state`
- `after_state`
- `metadata`

## Suggested Service Layer Split

- `AuthService`
- `MachineService`
- `CustomerService`
- `OrderService`
- `PaymentService`
- `ReservationService`
- `ActiveOrderSessionService`
- `AuditLogService`

## Suggested Repository Layer Split

- `UserRepository`
- `AuthSessionRepository`
- `MachineRepository`
- `CustomerRepository`
- `OrderRepository`
- `PaymentRepository`
- `ReservationRepository`
- `ActiveOrderSessionRepository`
- `MachineEventRepository`
- `AuditLogRepository`
