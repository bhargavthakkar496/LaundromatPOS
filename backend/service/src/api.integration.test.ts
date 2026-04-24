import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createServer, type Server } from "node:http";

import { createApp } from "./app.js";
import { pool } from "./db/pool.js";

type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue };

type ApiResponse<T = JsonValue> = {
  status: number;
  body: T | null;
  text: string;
};

let server: Server;
let baseUrl = "";
let authToken = "";

before(async () => {
  server = createServer(createApp());
  await new Promise<void>((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve());
  });
  const address = server.address();
  if (address == null || typeof address === "string") {
    throw new Error("Unable to determine integration test server address");
  }
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise<void>((resolve, reject) => {
    server.close((error) => {
      if (error != null) {
        reject(error);
        return;
      }
      resolve();
    });
  });
  await pool.end();
});

function uniquePhone(prefix: string) {
  const digits = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    .replace(/\D/g, "")
    .slice(-9)
    .padStart(9, "0");
  return `${prefix}${digits}`.slice(0, 10);
}

async function apiRequest<T = JsonValue>(
  path: string,
  options: {
    method?: string;
    authenticated?: boolean;
    body?: Record<string, unknown>;
  } = {},
): Promise<ApiResponse<T>> {
  const headers = new Headers({
    Accept: "application/json",
  });
  if (options.body != null) {
    headers.set("Content-Type", "application/json");
  }
  if (options.authenticated ?? true) {
    headers.set("Authorization", `Bearer ${authToken}`);
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method ?? "GET",
    headers,
    body: options.body == null ? undefined : JSON.stringify(options.body),
  });
  const text = await response.text();
  const body = text.length > 0 ? (JSON.parse(text) as T) : null;

  return {
    status: response.status,
    body,
    text,
  };
}

function assertOk<T>(response: ApiResponse<T>, expectedStatus = 200): T {
  assert.equal(
    response.status,
    expectedStatus,
    `Expected ${expectedStatus} but received ${response.status}: ${response.text}`,
  );
  return response.body as T;
}

async function latestAuditAction(entityType: string, entityId: string) {
  const result = await pool.query<{ action: string }>(
    `
      SELECT action
      FROM audit_logs
      WHERE entity_type = $1
        AND entity_id = $2
      ORDER BY id DESC
      LIMIT 1
    `,
    [entityType, entityId],
  );
  return result.rows[0]?.action ?? null;
}

async function loginAsAdmin() {
  const response = await apiRequest<{
    accessToken: string;
    user: { id: number; username: string };
  }>("/auth/login", {
    method: "POST",
    authenticated: false,
    body: {
      username: "admin",
      pin: "1234",
    },
  });
  const body = assertOk(response);
  assert.equal(body.user.username, "admin");
  authToken = body.accessToken;
  assert.match(authToken, /\S+/);
}

test("backend api integration flows", { concurrency: false }, async (t) => {
  await t.test("auth and machine inventory flow", async () => {
    await loginAsAdmin();

    const healthResponse = await apiRequest<{ ok: boolean }>("/health", {
      authenticated: false,
    });
    const health = assertOk(healthResponse);
    assert.equal(health.ok, true);

    const machinesResponse =
      await apiRequest<Array<{ id: number; type: string; status: string }>>(
        "/machines",
      );
    const machines = assertOk(machinesResponse);
    assert.ok(machines.length >= 2);
    assert.ok(
      machines.some((machine) => machine.type.toLowerCase() === "washer"),
    );
    assert.ok(
      machines.some((machine) => machine.type.toLowerCase() === "dryer"),
    );
  });

  await t.test('staff management data is served and updated from backend storage', async () => {
    const membersResponse = await apiRequest<
      Array<{ id: number; fullName: string; role: string }>
    >('/staff/members');
    const members = assertOk(membersResponse);
    assert.ok(members.length >= 4);
    const cashier = members.find((item) => item.fullName === 'Kiran Patel');
    assert.ok(cashier);

    const shiftsResponse = await apiRequest<
      Array<{ id: number; staffId: number; assignment: string }>
    >(
      `/staff/shifts?start=${encodeURIComponent(new Date('2026-01-01T00:00:00.000Z').toISOString())}&end=${encodeURIComponent(new Date('2030-01-01T00:00:00.000Z').toISOString())}`,
    );
    const shifts = assertOk(shiftsResponse);
    assert.ok(shifts.length >= 1);

    const createdShiftResponse = await apiRequest<{
      id: number;
      staffId: number;
      branch: string;
      assignment: string;
    }>('/staff/shifts', {
      method: 'POST',
      body: {
        staffId: cashier!.id,
        shiftDate: new Date().toISOString(),
        startTimeLabel: '11:00',
        endTimeLabel: '19:00',
        branch: 'Main Branch',
        assignment: 'Counter close support',
        hours: 8,
      },
    });
    const createdShift = assertOk(createdShiftResponse, 201);
    assert.equal(createdShift.staffId, cashier!.id);
    assert.equal(createdShift.assignment, 'Counter close support');

    const leaveResponse = await apiRequest<
      Array<{ id: number; status: string; reviewedByName: string | null }>
    >('/staff/leave-requests');
    const leaveRequests = assertOk(leaveResponse);
    assert.ok(leaveRequests.length >= 1);
    const pendingLeave = leaveRequests.find((item) => item.status === 'PENDING');
    assert.ok(pendingLeave);

    const updatedLeaveResponse = await apiRequest<{
      id: number;
      status: string;
      reviewedByName: string | null;
    }>(`/staff/leave-requests/${pendingLeave!.id}`, {
      method: 'PATCH',
      body: {
        status: 'APPROVED',
        reviewedByName: 'Integration Manager',
      },
    });
    const updatedLeave = assertOk(updatedLeaveResponse);
    assert.equal(updatedLeave.status, 'APPROVED');
    assert.equal(updatedLeave.reviewedByName, 'Integration Manager');

    const payoutsResponse = await apiRequest<
      Array<{ id: number; status: string }>
    >('/staff/payouts');
    const payouts = assertOk(payoutsResponse);
    assert.ok(payouts.length >= 1);

    const createdPayoutResponse = await apiRequest<{
      id: number;
      staffId: number;
      status: string;
      grossAmount: number;
      netAmount: number;
    }>('/staff/payouts', {
      method: 'POST',
      body: {
        staffId: cashier!.id,
        periodLabel: '16 Apr - 30 Apr',
        hoursWorked: 10,
        bonusAmount: 25,
        deductionsAmount: 5,
      },
    });
    const createdPayout = assertOk(createdPayoutResponse, 201);
    assert.equal(createdPayout.staffId, cashier!.id);
    assert.equal(createdPayout.status, 'SCHEDULED');
    assert.equal(createdPayout.grossAmount, 1200);
    assert.equal(createdPayout.netAmount, 1220);

    const paidPayoutResponse = await apiRequest<{
      id: number;
      status: string;
      paidAt: string | null;
    }>(`/staff/payouts/${createdPayout.id}/pay`, {
      method: 'POST',
      body: {},
    });
    const paidPayout = assertOk(paidPayoutResponse);
    assert.equal(paidPayout.status, 'PAID');
    assert.ok(paidPayout.paidAt);
  });

  await t.test(
    'maintenance flow moves a device from marked to ongoing to completed and restores availability',
    async () => {
      const machinesResponse = await apiRequest<
        Array<{ id: number; type: string; status: string }>
      >('/machines');
      const machines = assertOk(machinesResponse);
      const candidate = machines.find((machine) => machine.status === 'AVAILABLE');
      assert.ok(candidate);

      const createdResponse = await apiRequest<{
        id: number;
        machineId: number;
        status: string;
        priority: string;
      }>('/maintenance/records', {
        method: 'POST',
        body: {
          machineId: candidate!.id,
          issueTitle: 'Integration maintenance test',
          issueDescription: 'Validate maintenance lifecycle and machine status reflection.',
          priority: 'HIGH',
          reportedByName: 'Integration Test',
        },
      });
      const created = assertOk(createdResponse, 201);
      assert.equal(created.machineId, candidate!.id);
      assert.equal(created.status, 'MARKED');
      assert.equal(created.priority, 'HIGH');

      const machineMarkedResponse = await apiRequest<{ status: string }>(
        `/machines/${candidate!.id}`,
      );
      assert.equal(assertOk(machineMarkedResponse).status, 'MAINTENANCE');

      const startedResponse = await apiRequest<{ status: string; startedByName: string | null }>(
        `/maintenance/records/${created.id}/start`,
        {
          method: 'POST',
          body: {
            startedByName: 'Technician A',
          },
        },
      );
      const started = assertOk(startedResponse);
      assert.equal(started.status, 'IN_PROGRESS');
      assert.equal(started.startedByName, 'Technician A');

      const completedResponse = await apiRequest<{
        status: string;
        completedByName: string | null;
        resolutionNotes: string | null;
      }>(`/maintenance/records/${created.id}/complete`, {
        method: 'POST',
        body: {
          completedByName: 'Technician A',
          resolutionNotes: 'Sensor recalibrated and test cycle passed.',
        },
      });
      const completed = assertOk(completedResponse);
      assert.equal(completed.status, 'COMPLETED');
      assert.equal(completed.completedByName, 'Technician A');
      assert.equal(completed.resolutionNotes, 'Sensor recalibrated and test cycle passed.');

      const machineCompletedResponse = await apiRequest<{ status: string }>(
        `/machines/${candidate!.id}`,
      );
      assert.equal(assertOk(machineCompletedResponse).status, 'AVAILABLE');

      const completedListResponse = await apiRequest<Array<{ id: number; status: string }>>(
        '/maintenance/records?status=COMPLETED',
      );
      const completedList = assertOk(completedListResponse);
      assert.ok(completedList.some((item) => item.id === created.id));

      const auditAction = await latestAuditAction('maintenance_record', String(created.id));
      assert.equal(auditAction, 'maintenance.record_completed');
    },
  );

  await t.test(
    "inventory dashboard and filtered item queries work",
    async () => {
      const dashboardResponse = await apiRequest<{
        metrics: {
          lowStockCount: number;
          outOfStockCount: number;
          stockValue: number;
          pendingPurchaseOrders: number;
          expiringSoonCount: number;
        };
        categories: Array<{
          category: string;
          itemCount: number;
        }>;
        suppliers: string[];
        branches: string[];
        locations: string[];
      }>("/inventory/dashboard");
      const dashboard = assertOk(dashboardResponse);
      assert.ok(dashboard.metrics.lowStockCount >= 1);
      assert.ok(dashboard.metrics.pendingPurchaseOrders >= 1);
      assert.ok(
        dashboard.categories.some((item) => item.category === "Detergent"),
      );
      assert.ok(dashboard.suppliers.length >= 1);
      assert.ok(dashboard.branches.length >= 1);
      assert.ok(dashboard.locations.length >= 1);

      const filteredItemsResponse = await apiRequest<
        Array<{
          id: number;
          sku: string;
          barcode: string | null;
          category: string;
          packSize: string | null;
          unitType: string;
          parLevel: number;
          sellingPrice: number | null;
          stockStatus: string;
          supplier: string | null;
        }>
      >(
        "/inventory/items?category=Detergent&stockStatus=LOW&sortBy=quantity&sortOrder=asc",
      );
      const filteredItems = assertOk(filteredItemsResponse);
      assert.ok(filteredItems.length >= 1);
      assert.ok(filteredItems.every((item) => item.category === "Detergent"));
      assert.ok(filteredItems.every((item) => item.stockStatus === "LOW"));
      assert.ok(filteredItems.some((item) => item.sku == "DET-ULTRA-5KG"));
      assert.ok(filteredItems.every((item) => item.barcode != null));
      assert.ok(filteredItems.every((item) => item.packSize != null));
      assert.ok(filteredItems.every((item) => item.unitType.length > 0));
      assert.ok(filteredItems.every((item) => item.parLevel >= 0));

      const movementHistoryResponse = await apiRequest<
        Array<{
          inventoryItemId: number;
          movementType: string;
          quantityDelta: number;
          balanceAfter: number;
        }>
      >(`/inventory/items/${filteredItems[0].id}/movements`);
      const movementHistory = assertOk(movementHistoryResponse);
      assert.ok(movementHistory.length >= 1);
      assert.ok(
        movementHistory.every(
          (item) => item.inventoryItemId === filteredItems[0].id,
        ),
      );
      assert.ok(
        movementHistory.some((item) => item.movementType === "RECEIVED"),
      );
    },
  );

  await t.test(
    "inventory restock requests move from pending to procurement to healthy stock",
    async () => {
      await pool.query(
        `
          DELETE FROM inventory_purchase_orders
          WHERE restock_request_id IN (
            SELECT id
            FROM inventory_restock_requests
            WHERE inventory_item_id = 12
          );
        `,
      );
      await pool.query(
        `
          DELETE FROM inventory_restock_requests
          WHERE inventory_item_id = 12;
        `,
      );
      await pool.query(
        `
          UPDATE inventory_items
          SET quantity_on_hand = 0,
              last_restocked_at = NOW() - INTERVAL '19 days',
              updated_at = NOW()
          WHERE id = 12;
        `,
      );

      const beforeDashboardResponse = await apiRequest<{
        metrics: { pendingPurchaseOrders: number };
      }>("/inventory/dashboard");
      const beforeDashboard = assertOk(beforeDashboardResponse);

      const outOfStockItemsResponse = await apiRequest<
        Array<{
          id: number;
          sku: string;
          quantityOnHand: number;
          reorderPoint: number;
          activeRestockRequestId: number | null;
        }>
      >("/inventory/items?stockStatus=OUT_OF_STOCK");
      const outOfStockItems = assertOk(outOfStockItemsResponse);
      assert.ok(outOfStockItems.length >= 1);

      const targetItem = outOfStockItems.find(
        (item) => item.id === 12 && item.activeRestockRequestId == null,
      );
      assert.ok(
        targetItem,
        "Expected at least one out-of-stock item without an active request",
      );

      const createRequestResponse = await apiRequest<{
        id: number;
        inventoryItemId: number;
        status: string;
        requestedQuantity: number;
      }>("/inventory/restock-requests", {
        method: "POST",
        body: {
          inventoryItemId: targetItem!.id,
          requestedQuantity: targetItem!.reorderPoint,
        },
      });
      const createdRequest = assertOk(createRequestResponse, 201);
      assert.equal(createdRequest.inventoryItemId, targetItem!.id);
      assert.equal(createdRequest.status, "PENDING");

      const pendingRequestsResponse = await apiRequest<
        Array<{ id: number; status: string; inventoryItemId: number }>
      >("/inventory/restock-requests?status=PENDING");
      const pendingRequests = assertOk(pendingRequestsResponse);
      assert.ok(pendingRequests.some((item) => item.id === createdRequest.id));

      const approveResponse = await apiRequest<{
        id: number;
        status: string;
        operatorRemarks: string;
      }>(`/inventory/restock-requests/${createdRequest.id}/approve`, {
        method: "POST",
        body: {
          operatorRemarks:
            "Approved for urgent replenishment on next supplier cycle.",
        },
      });
      const approvedRequest = assertOk(approveResponse);
      assert.equal(approvedRequest.id, createdRequest.id);
      assert.equal(approvedRequest.status, "APPROVED");

      const inProcurementItemsResponse = await apiRequest<
        Array<{
          id: number;
          stockStatus: string;
          activeRestockRequestStatus: string | null;
          activeRestockOperatorRemarks: string | null;
        }>
      >("/inventory/items?stockStatus=IN_PROCUREMENT");
      const inProcurementItems = assertOk(inProcurementItemsResponse);
      const inProcurementItem = inProcurementItems.find(
        (item) => item.id === targetItem!.id,
      );
      assert.ok(inProcurementItem);
      assert.equal(inProcurementItem!.stockStatus, "IN_PROCUREMENT");
      assert.equal(inProcurementItem!.activeRestockRequestStatus, "APPROVED");
      assert.ok(inProcurementItem!.activeRestockOperatorRemarks);

      const afterDashboardResponse = await apiRequest<{
        metrics: { pendingPurchaseOrders: number };
      }>("/inventory/dashboard");
      const afterDashboard = assertOk(afterDashboardResponse);
      assert.equal(
        afterDashboard.metrics.pendingPurchaseOrders,
        beforeDashboard.metrics.pendingPurchaseOrders + 1,
      );

      const procureResponse = await apiRequest<{
        id: number;
        status: string;
      }>(`/inventory/restock-requests/${createdRequest.id}/procure`, {
        method: "POST",
      });
      const procuredRequest = assertOk(procureResponse);
      assert.equal(procuredRequest.status, "PROCURED");

      const procuredHistoryResponse = await apiRequest<
        Array<{
          referenceType: string | null;
          movementType: string;
        }>
      >(`/inventory/items/${targetItem!.id}/movements`);
      const procuredHistory = assertOk(procuredHistoryResponse);
      assert.ok(
        procuredHistory.some(
          (item) =>
            item.movementType === "RECEIVED" &&
            item.referenceType === "RESTOCK_REQUEST",
        ),
      );

      const healthyItemsResponse = await apiRequest<
        Array<{
          id: number;
          stockStatus: string;
          quantityOnHand: number;
          reorderPoint: number;
        }>
      >("/inventory/items?stockStatus=HEALTHY");
      const healthyItems = assertOk(healthyItemsResponse);
      const healedItem = healthyItems.find((item) => item.id === targetItem!.id);
      assert.ok(healedItem);
      assert.equal(healedItem!.stockStatus, "HEALTHY");
      assert.ok(healedItem!.quantityOnHand > healedItem!.reorderPoint);
    },
  );

  await t.test(
    'pricing endpoints update rates, fees, campaigns, and quote-backed order totals',
    async () => {
      const currentSessionResponse = await apiRequest('/active-order-session');
      if (currentSessionResponse.status === 200) {
        const cleared = await apiRequest('/active-order-session', {
          method: 'DELETE',
        });
        assert.equal(cleared.status, 204);
      }

      const machinesResponse = await apiRequest<
        Array<{ id: number; name: string; type: string; status: string; price: number }>
      >('/machines');
      const machines = assertOk(machinesResponse);
      const washer = machines.find(
        (machine) =>
          machine.type.toLowerCase() === 'washer' &&
          machine.status === 'AVAILABLE',
      );
      const dryer = machines.find(
        (machine) =>
          machine.type.toLowerCase() === 'dryer' &&
          machine.status === 'AVAILABLE',
      );
      assert.ok(washer);
      assert.ok(dryer);

      const feesResponse = await apiRequest<
        Array<{ serviceCode: string; amount: number; isEnabled: boolean }>
      >('/pricing/service-fees');
      const fees = assertOk(feesResponse);
      const washingFee = fees.find((item) => item.serviceCode === 'Washing');
      assert.ok(washingFee);

      const originalWasherPrice = washer!.price;
      const originalWashingFeeAmount = washingFee!.amount;
      const originalWashingFeeEnabled = washingFee!.isEnabled;

      let campaignId: number | null = null;

      try {
        const updatedMachineResponse = await apiRequest<{ price: number }>(
          `/pricing/machines/${washer!.id}`,
          {
            method: 'PATCH',
            body: {
              price: originalWasherPrice + 23,
            },
          },
        );
        const updatedMachine = assertOk(updatedMachineResponse);
        assert.equal(updatedMachine.price, originalWasherPrice + 23);

        const updatedFeeResponse = await apiRequest<{
          amount: number;
          isEnabled: boolean;
        }>(`/pricing/service-fees/Washing`, {
          method: 'PATCH',
          body: {
            amount: originalWashingFeeAmount + 7,
            isEnabled: true,
          },
        });
        const updatedFee = assertOk(updatedFeeResponse);
        assert.equal(updatedFee.amount, originalWashingFeeAmount + 7);
        assert.equal(updatedFee.isEnabled, true);

        const createdCampaignResponse = await apiRequest<{
          id: number;
          isActive: boolean;
          discountType: string;
        }>('/pricing/campaigns', {
          method: 'POST',
          body: {
            name: 'Integration Pricing Campaign',
            description: 'Covers backend pricing flow validation.',
            discountType: 'PERCENT',
            discountValue: 10,
            appliesToService: 'ALL',
            minOrderAmount: 0,
            isActive: true,
          },
        });
        const createdCampaign = assertOk(createdCampaignResponse, 201);
        campaignId = createdCampaign.id;
        assert.equal(createdCampaign.isActive, true);
        assert.equal(createdCampaign.discountType, 'PERCENT');

        const quoteResponse = await apiRequest<{
          machineSubtotal: number;
          serviceFeeTotal: number;
          discountTotal: number;
          finalTotal: number;
          appliedCampaigns: Array<{ id: number }>;
        }>('/pricing/quote', {
          method: 'POST',
          body: {
            washerMachineId: washer!.id,
            dryerMachineId: dryer!.id,
            selectedServices: ['Washing', 'Drying'],
          },
        });
        const quote = assertOk(quoteResponse);
        assert.equal(
          quote.machineSubtotal,
          originalWasherPrice + 23 + dryer!.price,
        );
        assert.equal(quote.serviceFeeTotal, originalWashingFeeAmount + 7 + 10);
        assert.ok(quote.discountTotal > 0);
        assert.ok(
          quote.appliedCampaigns.some((item) => item.id === createdCampaign.id),
        );

        const phone = uniquePhone('5');
        const draftResponse = await apiRequest<{ stage: string }>(
          '/active-order-session/draft',
          {
            method: 'POST',
            body: {
              customerName: 'Pricing Integration Test',
              customerPhone: phone,
              loadSizeKg: 9,
              selectedServices: ['Washing', 'Drying'],
              washOption: 'Express Wash',
              washerMachineId: washer!.id,
              dryerMachineId: dryer!.id,
              paymentMethod: 'Card',
            },
          },
        );
        assert.equal(assertOk(draftResponse).stage, 'DRAFT');

        const confirmedResponse = await apiRequest<{
          stage: string;
          orderId: number;
        }>('/active-order-session/confirm', {
          method: 'POST',
          body: {
            confirmedBy: 'Operator',
          },
        });
        const confirmed = assertOk(confirmedResponse);
        assert.equal(confirmed.stage, 'BOOKED');

        const orderHistoryResponse = await apiRequest<{
          order: { amount: number; paymentStatus: string };
        }>(`/orders/${confirmed.orderId}/history-item`);
        const orderHistory = assertOk(orderHistoryResponse);
        assert.equal(orderHistory.order.paymentStatus, 'PENDING');
        assert.equal(orderHistory.order.amount, quote.finalTotal);

        const clearResponse = await apiRequest('/active-order-session', {
          method: 'DELETE',
        });
        assert.equal(clearResponse.status, 204);
      } finally {
        await apiRequest(`/pricing/machines/${washer!.id}`, {
          method: 'PATCH',
          body: {
            price: originalWasherPrice,
          },
        });
        await apiRequest('/pricing/service-fees/Washing', {
          method: 'PATCH',
          body: {
            amount: originalWashingFeeAmount,
            isEnabled: originalWashingFeeEnabled,
          },
        });
        if (campaignId != null) {
          await apiRequest(`/pricing/campaigns/${campaignId}`, {
            method: 'PATCH',
            body: {
              isActive: false,
            },
          });
        }
        try {
          await apiRequest('/active-order-session', { method: 'DELETE' });
        } catch {
          // Ignore cleanup failures if no active session remains.
        }
      }
    },
  );

  await t.test("customer reservation flow writes audit history", async () => {
    const phone = uniquePhone("8");
    const customerResponse = await apiRequest<{
      id: number;
      fullName: string;
      phone: string;
    }>("/customers/walk-in", {
      method: "POST",
      body: {
        fullName: "Backend Reservation Test",
        phone,
        preferredWasherSizeKg: 8,
        preferredDetergentAddOn: "Softener",
        preferredDryerDurationMinutes: 30,
      },
    });
    const customer = assertOk(customerResponse);
    assert.equal(customer.phone, phone);

    const startTime = new Date(Date.now() + 26 * 60 * 60 * 1000);
    const endTime = new Date(startTime.getTime() + 60 * 60 * 1000);

    const reservableResponse = await apiRequest<
      Array<{ id: number; type: string }>
    >(
      `/machines/reservable?machineType=washer&startTime=${encodeURIComponent(startTime.toISOString())}&endTime=${encodeURIComponent(endTime.toISOString())}`,
    );
    const reservableMachines = assertOk(reservableResponse);
    assert.ok(reservableMachines.length > 0);

    const reservationResponse = await apiRequest<{
      id: number;
      machineId: number;
      customerId: number;
      status: string;
    }>("/reservations", {
      method: "POST",
      body: {
        machineId: reservableMachines[0].id,
        customerId: customer.id,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
        preferredWasherSizeKg: 8,
        detergentAddOn: "Softener",
        dryerDurationMinutes: 30,
      },
    });
    const reservation = assertOk(reservationResponse);
    assert.equal(reservation.customerId, customer.id);
    assert.equal(reservation.status, "BOOKED");

    const profileResponse = await apiRequest<{
      customer: { id: number; phone: string };
      upcomingReservations: Array<{ reservation: { id: number } }>;
    }>(`/customers/profile?phone=${phone}`);
    const profile = assertOk(profileResponse);
    assert.equal(profile.customer.id, customer.id);
    assert.ok(
      profile.upcomingReservations.some(
        (item) => item.reservation.id === reservation.id,
      ),
    );

    const auditAction = await latestAuditAction(
      "reservation",
      String(reservation.id),
    );
    assert.equal(auditAction, "reservation.create");
  });

  await t.test(
    "active order payment flow updates order and machine state",
    async () => {
      const currentSessionResponse = await apiRequest("/active-order-session");
      if (currentSessionResponse.status === 200) {
        const cleared = await apiRequest("/active-order-session", {
          method: "DELETE",
        });
        assert.equal(cleared.status, 204);
      } else {
        assert.equal(currentSessionResponse.status, 404);
      }

      const machinesResponse =
        await apiRequest<Array<{ id: number; type: string; status: string }>>(
          "/machines",
        );
      const machines = assertOk(machinesResponse);
      const washer = machines.find(
        (machine) =>
          machine.type.toLowerCase() === "washer" &&
          machine.status === "AVAILABLE",
      );
      const dryer = machines.find(
        (machine) =>
          machine.type.toLowerCase() === "dryer" &&
          machine.status === "AVAILABLE",
      );
      assert.ok(washer, "Expected at least one available washer");
      assert.ok(dryer, "Expected at least one available dryer");

      const phone = uniquePhone("7");
      const draftResponse = await apiRequest<{
        stage: string;
      }>("/active-order-session/draft", {
        method: "POST",
        body: {
          customerName: "Backend Active Session Test",
          customerPhone: phone,
          loadSizeKg: 8,
          selectedServices: ["Washing", "Drying"],
          washOption: "Gentle Wash",
          washerMachineId: washer!.id,
          dryerMachineId: dryer!.id,
          paymentMethod: "Card",
        },
      });
      const draft = assertOk(draftResponse);
      assert.equal(draft.stage, "DRAFT");

      const confirmResponse = await apiRequest<{
        stage: string;
        orderId: number;
      }>("/active-order-session/confirm", {
        method: "POST",
        body: {
          confirmedBy: "Customer",
        },
      });
      const confirmed = assertOk(confirmResponse);
      assert.equal(confirmed.stage, "BOOKED");
      assert.ok(confirmed.orderId > 0);

      const paymentReference = `BOOK-INTEGRATION-${Date.now()}`;
      const paymentResponse = await apiRequest<{
        stage: string;
        orderId: number;
        paymentReference: string;
      }>("/active-order-session/payment", {
        method: "POST",
        body: {
          paymentReference,
        },
      });
      const paid = assertOk(paymentResponse);
      assert.equal(paid.stage, "PAID");
      assert.equal(paid.orderId, confirmed.orderId);
      assert.equal(paid.paymentReference, paymentReference);

      const orderHistoryResponse = await apiRequest<{
        order: { id: number; paymentStatus: string; paymentReference: string };
        machine: { id: number; status: string };
      }>(`/orders/${paid.orderId}/history-item`);
      const orderHistory = assertOk(orderHistoryResponse);
      assert.equal(orderHistory.order.paymentStatus, "PAID");
      assert.equal(orderHistory.order.paymentReference, paymentReference);
      assert.equal(orderHistory.machine.id, washer!.id);

      const paymentSessionResponse = await apiRequest<{
        id: number;
        status: string;
      }>("/payments/sessions", {
        method: "POST",
        body: {
          amount: 120,
          paymentMethod: "UPI",
          referencePrefix: "TEST",
        },
      });
      const paymentSession = assertOk(paymentSessionResponse);
      assert.equal(paymentSession.status, "AWAITING_SCAN");

      const polledPaymentSessionResponse = await apiRequest<{
        id: number;
        status: string;
      }>(`/payments/sessions/${paymentSession.id}`);
      const polledPaymentSession = assertOk(polledPaymentSessionResponse);
      assert.equal(polledPaymentSession.id, paymentSession.id);
      assert.ok(
        ["AWAITING_SCAN", "PROCESSING", "PAID"].includes(
          polledPaymentSession.status,
        ),
      );

      const pickupResponse = await apiRequest(
        `/machines/${washer!.id}/pickup`,
        {
          method: "POST",
        },
      );
      assert.equal(pickupResponse.status, 200);

      const clearResponse = await apiRequest("/active-order-session", {
        method: "DELETE",
      });
      assert.equal(clearResponse.status, 204);

      const auditAction = await latestAuditAction(
        "machine",
        String(washer!.id),
      );
      assert.equal(auditAction, "machine.pickup");
    },
  );
});
