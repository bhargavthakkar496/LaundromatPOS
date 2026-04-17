import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createServer, type Server } from 'node:http';

import { createApp } from './app.js';
import { pool } from './db/pool.js';

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
let baseUrl = '';
let authToken = '';

before(async () => {
  server = createServer(createApp());
  await new Promise<void>((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve());
  });
  const address = server.address();
  if (address == null || typeof address === 'string') {
    throw new Error('Unable to determine integration test server address');
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
    .replace(/\D/g, '')
    .slice(-9)
    .padStart(9, '0');
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
    Accept: 'application/json',
  });
  if (options.body != null) {
    headers.set('Content-Type', 'application/json');
  }
  if (options.authenticated ?? true) {
    headers.set('Authorization', `Bearer ${authToken}`);
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method ?? 'GET',
    headers,
    body: options.body == null ? undefined : JSON.stringify(options.body),
  });
  const text = await response.text();
  const body =
    text.length > 0 ? (JSON.parse(text) as T) : null;

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
  }>('/auth/login', {
    method: 'POST',
    authenticated: false,
    body: {
      username: 'admin',
      pin: '1234',
    },
  });
  const body = assertOk(response);
  assert.equal(body.user.username, 'admin');
  authToken = body.accessToken;
  assert.match(authToken, /\S+/);
}

test(
  'backend api integration flows',
  { concurrency: false },
  async (t) => {
    await t.test('auth and machine inventory flow', async () => {
      await loginAsAdmin();

      const healthResponse = await apiRequest<{ ok: boolean }>('/health', {
        authenticated: false,
      });
      const health = assertOk(healthResponse);
      assert.equal(health.ok, true);

      const machinesResponse = await apiRequest<
        Array<{ id: number; type: string; status: string }>
      >('/machines');
      const machines = assertOk(machinesResponse);
      assert.ok(machines.length >= 2);
      assert.ok(machines.some((machine) => machine.type.toLowerCase() === 'washer'));
      assert.ok(machines.some((machine) => machine.type.toLowerCase() === 'dryer'));
    });

    await t.test('customer reservation flow writes audit history', async () => {
      const phone = uniquePhone('8');
      const customerResponse = await apiRequest<{
        id: number;
        fullName: string;
        phone: string;
      }>('/customers/walk-in', {
        method: 'POST',
        body: {
          fullName: 'Backend Reservation Test',
          phone,
          preferredWasherSizeKg: 8,
          preferredDetergentAddOn: 'Softener',
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
      }>('/reservations', {
        method: 'POST',
        body: {
          machineId: reservableMachines[0].id,
          customerId: customer.id,
          startTime: startTime.toISOString(),
          endTime: endTime.toISOString(),
          preferredWasherSizeKg: 8,
          detergentAddOn: 'Softener',
          dryerDurationMinutes: 30,
        },
      });
      const reservation = assertOk(reservationResponse);
      assert.equal(reservation.customerId, customer.id);
      assert.equal(reservation.status, 'BOOKED');

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
        'reservation',
        String(reservation.id),
      );
      assert.equal(auditAction, 'reservation.create');
    });

    await t.test('active order payment flow updates order and machine state', async () => {
      const currentSessionResponse = await apiRequest('/active-order-session');
      if (currentSessionResponse.status === 200) {
        const cleared = await apiRequest('/active-order-session', {
          method: 'DELETE',
        });
        assert.equal(cleared.status, 204);
      } else {
        assert.equal(currentSessionResponse.status, 404);
      }

      const machinesResponse = await apiRequest<
        Array<{ id: number; type: string; status: string }>
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
      assert.ok(washer, 'Expected at least one available washer');
      assert.ok(dryer, 'Expected at least one available dryer');

      const phone = uniquePhone('7');
      const draftResponse = await apiRequest<{
        stage: string;
      }>('/active-order-session/draft', {
        method: 'POST',
        body: {
          customerName: 'Backend Active Session Test',
          customerPhone: phone,
          loadSizeKg: 8,
          washOption: 'Gentle Wash',
          washerMachineId: washer!.id,
          dryerMachineId: dryer!.id,
          paymentMethod: 'Card',
        },
      });
      const draft = assertOk(draftResponse);
      assert.equal(draft.stage, 'DRAFT');

      const confirmResponse = await apiRequest<{
        stage: string;
        orderId: number;
      }>('/active-order-session/confirm', {
        method: 'POST',
        body: {
          confirmedBy: 'Customer',
        },
      });
      const confirmed = assertOk(confirmResponse);
      assert.equal(confirmed.stage, 'BOOKED');
      assert.ok(confirmed.orderId > 0);

      const paymentReference = `BOOK-INTEGRATION-${Date.now()}`;
      const paymentResponse = await apiRequest<{
        stage: string;
        orderId: number;
        paymentReference: string;
      }>('/active-order-session/payment', {
        method: 'POST',
        body: {
          paymentReference,
        },
      });
      const paid = assertOk(paymentResponse);
      assert.equal(paid.stage, 'PAID');
      assert.equal(paid.orderId, confirmed.orderId);
      assert.equal(paid.paymentReference, paymentReference);

      const orderHistoryResponse = await apiRequest<{
        order: { id: number; paymentStatus: string; paymentReference: string };
        machine: { id: number; status: string };
      }>(`/orders/${paid.orderId}/history-item`);
      const orderHistory = assertOk(orderHistoryResponse);
      assert.equal(orderHistory.order.paymentStatus, 'PAID');
      assert.equal(orderHistory.order.paymentReference, paymentReference);
      assert.equal(orderHistory.machine.id, washer!.id);

      const paymentSessionResponse = await apiRequest<{
        id: number;
        status: string;
      }>('/payments/sessions', {
        method: 'POST',
        body: {
          amount: 120,
          paymentMethod: 'UPI',
          referencePrefix: 'TEST',
        },
      });
      const paymentSession = assertOk(paymentSessionResponse);
      assert.equal(paymentSession.status, 'AWAITING_SCAN');

      const polledPaymentSessionResponse = await apiRequest<{
        id: number;
        status: string;
      }>(`/payments/sessions/${paymentSession.id}`);
      const polledPaymentSession = assertOk(polledPaymentSessionResponse);
      assert.equal(polledPaymentSession.id, paymentSession.id);
      assert.ok(
        ['AWAITING_SCAN', 'PROCESSING', 'PAID'].includes(
          polledPaymentSession.status,
        ),
      );

      const pickupResponse = await apiRequest(`/machines/${washer!.id}/pickup`, {
        method: 'POST',
      });
      assert.equal(pickupResponse.status, 200);

      const clearResponse = await apiRequest('/active-order-session', {
        method: 'DELETE',
      });
      assert.equal(clearResponse.status, 204);

      const auditAction = await latestAuditAction('machine', String(washer!.id));
      assert.equal(auditAction, 'machine.pickup');
    });
  },
);
