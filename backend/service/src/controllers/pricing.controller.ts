import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import {
  calculatePricingQuote,
  type PricingCampaignRow,
  type PricingServiceFeeRow,
} from '../services/pricing.service.js';
import {
  serializeMachine,
  serializePricingCampaign,
  serializePricingQuote,
  serializePricingServiceFee,
} from '../services/serializers.js';

type MachineRow = {
  id: number;
  name: string;
  type: string;
  capacity_kg: number;
  price: number | string;
  status: string;
  current_order_id: number | null;
  cycle_started_at: Date | string | null;
  cycle_ends_at: Date | string | null;
};

const machineIdSchema = z.coerce.number().int().positive();
const campaignIdSchema = z.coerce.number().int().positive();
const serviceCodeSchema = z.enum(['Washing', 'Drying', 'Ironing']);
const discountTypeSchema = z.enum(['PERCENT', 'FIXED']);

const updateMachinePriceSchema = z.object({
  price: z.number().positive(),
});

const updateServiceFeeSchema = z.object({
  amount: z.number().min(0),
  isEnabled: z.boolean(),
});

const campaignWriteSchema = z.object({
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(500).nullable().optional(),
  discountType: discountTypeSchema,
  discountValue: z.number().positive(),
  appliesToService: z.union([serviceCodeSchema, z.literal('ALL')]).optional(),
  minOrderAmount: z.number().min(0).default(0),
  isActive: z.boolean().default(true),
  startsAt: z.string().datetime().nullable().optional(),
  endsAt: z.string().datetime().nullable().optional(),
});

const updateCampaignSchema = campaignWriteSchema.partial();

const campaignListQuerySchema = z.object({
  activeOnly: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

const previewQuoteSchema = z.object({
  washerMachineId: z.number().int().positive().nullable().optional(),
  dryerMachineId: z.number().int().positive().nullable().optional(),
  ironingMachineId: z.number().int().positive().nullable().optional(),
  selectedServices: z.array(serviceCodeSchema).min(1),
});

async function fetchServiceFees() {
  const result = await query<PricingServiceFeeRow>(
    `
      SELECT service_code, display_name, amount, is_enabled, updated_at
      FROM pricing_service_fees
      ORDER BY service_code ASC
    `,
  );
  return result.rows;
}

async function fetchCampaigns(activeOnly: boolean) {
  const result = await query<PricingCampaignRow>(
    `
      SELECT
        id,
        name,
        description,
        discount_type,
        discount_value,
        applies_to_service,
        min_order_amount,
        is_active,
        starts_at,
        ends_at,
        created_at,
        updated_at
      FROM pricing_campaigns
      ${activeOnly ? 'WHERE is_active = TRUE' : ''}
      ORDER BY is_active DESC, created_at DESC, id DESC
    `,
  );
  return result.rows;
}

export async function listPricingServiceFeesHandler(
  _request: Request,
  response: Response,
) {
  const rows = await fetchServiceFees();
  response.json(rows.map((row) => serializePricingServiceFee(row)));
}

export async function updateMachinePriceHandler(
  request: Request,
  response: Response,
) {
  const parsedId = machineIdSchema.safeParse(request.params.machineId);
  const parsedBody = updateMachinePriceSchema.safeParse(request.body);
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({ error: 'invalid_pricing_machine_request' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const updated = await withTransaction(async (client) => {
    const current = await client.query<MachineRow>(
      `
        SELECT
          id,
          name,
          type,
          capacity_kg,
          price,
          status,
          current_order_id,
          cycle_started_at,
          cycle_ends_at
        FROM machines
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );
    if (current.rowCount === 0) {
      return null;
    }

    const before = current.rows[0];
    const result = await client.query<MachineRow>(
      `
        UPDATE machines
        SET price = $2,
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          name,
          type,
          capacity_kg,
          price,
          status,
          current_order_id,
          cycle_started_at,
          cycle_ends_at
      `,
      [parsedId.data, parsedBody.data.price],
    );
    const after = result.rows[0];

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'pricing.machine_rate_updated',
      entityType: 'machine',
      entityId: String(parsedId.data),
      beforeState: serializeMachine(before),
      afterState: serializeMachine(after),
    });

    return after;
  });

  if (updated == null) {
    response.status(404).json({ error: 'not_found', detail: 'Machine not found' });
    return;
  }

  response.json(serializeMachine(updated));
}

export async function updatePricingServiceFeeHandler(
  request: Request,
  response: Response,
) {
  const parsedCode = serviceCodeSchema.safeParse(request.params.serviceCode);
  const parsedBody = updateServiceFeeSchema.safeParse(request.body);
  if (!parsedCode.success || !parsedBody.success) {
    response.status(400).json({ error: 'invalid_pricing_service_fee_request' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const updated = await withTransaction(async (client) => {
    const current = await client.query<PricingServiceFeeRow>(
      `
        SELECT service_code, display_name, amount, is_enabled, updated_at
        FROM pricing_service_fees
        WHERE service_code = $1
        FOR UPDATE
      `,
      [parsedCode.data],
    );
    if (current.rowCount === 0) {
      return null;
    }

    const before = current.rows[0];
    const result = await client.query<PricingServiceFeeRow>(
      `
        UPDATE pricing_service_fees
        SET amount = $2,
            is_enabled = $3,
            updated_at = NOW()
        WHERE service_code = $1
        RETURNING service_code, display_name, amount, is_enabled, updated_at
      `,
      [parsedCode.data, parsedBody.data.amount, parsedBody.data.isEnabled],
    );
    const after = result.rows[0];

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'pricing.service_fee_updated',
      entityType: 'pricing_service_fee',
      entityId: parsedCode.data,
      beforeState: serializePricingServiceFee(before),
      afterState: serializePricingServiceFee(after),
    });

    return after;
  });

  if (updated == null) {
    response.status(404).json({ error: 'not_found', detail: 'Service fee not found' });
    return;
  }

  response.json(serializePricingServiceFee(updated));
}

export async function listPricingCampaignsHandler(
  request: Request,
  response: Response,
) {
  const parsed = campaignListQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({ error: 'invalid_pricing_campaign_query' });
    return;
  }
  const rows = await fetchCampaigns(parsed.data.activeOnly);
  response.json(rows.map((row) => serializePricingCampaign(row)));
}

export async function createPricingCampaignHandler(
  request: Request,
  response: Response,
) {
  const parsed = campaignWriteSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: 'invalid_pricing_campaign_payload' });
    return;
  }
  const authUserId = response.locals.authUserId as number | undefined;

  const created = await withTransaction(async (client) => {
    const result = await client.query<PricingCampaignRow>(
      `
        INSERT INTO pricing_campaigns (
          name,
          description,
          discount_type,
          discount_value,
          applies_to_service,
          min_order_amount,
          is_active,
          starts_at,
          ends_at,
          created_at,
          updated_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),NOW())
        RETURNING
          id,
          name,
          description,
          discount_type,
          discount_value,
          applies_to_service,
          min_order_amount,
          is_active,
          starts_at,
          ends_at,
          created_at,
          updated_at
      `,
      [
        parsed.data.name,
        parsed.data.description ?? null,
        parsed.data.discountType,
        parsed.data.discountValue,
        parsed.data.appliesToService == null || parsed.data.appliesToService === 'ALL'
          ? 'ALL'
          : parsed.data.appliesToService,
        parsed.data.minOrderAmount,
        parsed.data.isActive,
        parsed.data.startsAt ?? null,
        parsed.data.endsAt ?? null,
      ],
    );
    const row = result.rows[0];

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'pricing.campaign_created',
      entityType: 'pricing_campaign',
      entityId: String(row.id),
      afterState: serializePricingCampaign(row),
    });

    return row;
  });

  response.status(201).json(serializePricingCampaign(created));
}

export async function updatePricingCampaignHandler(
  request: Request,
  response: Response,
) {
  const parsedId = campaignIdSchema.safeParse(request.params.campaignId);
  const parsedBody = updateCampaignSchema.safeParse(request.body);
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({ error: 'invalid_pricing_campaign_payload' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const updated = await withTransaction(async (client) => {
    const current = await client.query<PricingCampaignRow>(
      `
        SELECT
          id,
          name,
          description,
          discount_type,
          discount_value,
          applies_to_service,
          min_order_amount,
          is_active,
          starts_at,
          ends_at,
          created_at,
          updated_at
        FROM pricing_campaigns
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );
    if (current.rowCount === 0) {
      return null;
    }

    const before = current.rows[0];
    const body = parsedBody.data;
    const result = await client.query<PricingCampaignRow>(
      `
        UPDATE pricing_campaigns
        SET name = $2,
            description = $3,
            discount_type = $4,
            discount_value = $5,
            applies_to_service = $6,
            min_order_amount = $7,
            is_active = $8,
            starts_at = $9,
            ends_at = $10,
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          name,
          description,
          discount_type,
          discount_value,
          applies_to_service,
          min_order_amount,
          is_active,
          starts_at,
          ends_at,
          created_at,
          updated_at
      `,
      [
        parsedId.data,
        body.name ?? before.name,
        body.description === undefined ? before.description : body.description,
        body.discountType ?? before.discount_type,
        body.discountValue ?? Number(before.discount_value),
        body.appliesToService === undefined
          ? before.applies_to_service
          : body.appliesToService === 'ALL'
            ? 'ALL'
            : body.appliesToService,
        body.minOrderAmount ?? Number(before.min_order_amount),
        body.isActive ?? before.is_active,
        body.startsAt === undefined ? before.starts_at : body.startsAt,
        body.endsAt === undefined ? before.ends_at : body.endsAt,
      ],
    );
    const after = result.rows[0];

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'pricing.campaign_updated',
      entityType: 'pricing_campaign',
      entityId: String(parsedId.data),
      beforeState: serializePricingCampaign(before),
      afterState: serializePricingCampaign(after),
    });

    return after;
  });

  if (updated == null) {
    response.status(404).json({ error: 'not_found', detail: 'Campaign not found' });
    return;
  }

  response.json(serializePricingCampaign(updated));
}

export async function previewPricingQuoteHandler(
  request: Request,
  response: Response,
) {
  const parsed = previewQuoteSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: 'invalid_pricing_quote_request' });
    return;
  }

  const quote = await withTransaction((client) =>
    calculatePricingQuote(client, {
      machineIds: [
        parsed.data.washerMachineId,
        parsed.data.dryerMachineId,
        parsed.data.ironingMachineId,
      ].filter((value): value is number => value != null),
      selectedServices: parsed.data.selectedServices,
    }),
  );

  response.json(serializePricingQuote(quote));
}