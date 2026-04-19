import type { PoolClient } from 'pg';

export type PricingServiceFeeRow = {
  service_code: string;
  display_name: string;
  amount: number | string;
  is_enabled: boolean;
  updated_at: Date | string;
};

export type PricingCampaignRow = {
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
};

export type PricingMachineRow = {
  id: number;
  name: string;
  type: string;
  price: number | string;
};

export type PricingQuoteResult = {
  machineSubtotal: number;
  serviceFeeTotal: number;
  discountTotal: number;
  finalTotal: number;
  appliedCampaigns: PricingCampaignRow[];
  lines: Array<{
    label: string;
    type: 'MACHINE' | 'SERVICE_FEE' | 'DISCOUNT';
    amount: number;
  }>;
};

export async function calculatePricingQuote(
  client: PoolClient,
  input: {
    machineIds: number[];
    selectedServices: string[];
  },
): Promise<PricingQuoteResult> {
  const machineIds = [...new Set(input.machineIds)];
  const selectedServices = [...new Set(input.selectedServices)];

  const machineRows = machineIds.length === 0
    ? []
    : (
        await client.query<PricingMachineRow>(
          `
            SELECT id, name, type, price
            FROM machines
            WHERE id = ANY($1::bigint[])
            ORDER BY id ASC
          `,
          [machineIds],
        )
      ).rows;

  if (machineRows.length !== machineIds.length) {
    throw new Error('One or more pricing machines were not found');
  }

  const serviceFeeRows = selectedServices.length === 0
    ? []
    : (
        await client.query<PricingServiceFeeRow>(
          `
            SELECT service_code, display_name, amount, is_enabled, updated_at
            FROM pricing_service_fees
            WHERE service_code = ANY($1::text[])
            ORDER BY service_code ASC
          `,
          [selectedServices],
        )
      ).rows;

  const campaignRows = (
    await client.query<PricingCampaignRow>(
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
        ORDER BY is_active DESC, created_at DESC, id DESC
      `,
    )
  ).rows;

  const machineSubtotal = machineRows.reduce(
    (sum, row) => sum + Number(row.price),
    0,
  );
  const enabledServiceFees = serviceFeeRows.filter((row) => row.is_enabled);
  const serviceFeeTotal = enabledServiceFees.reduce(
    (sum, row) => sum + Number(row.amount),
    0,
  );
  const baseTotal = machineSubtotal + serviceFeeTotal;
  const now = new Date();

  let discountTotal = 0;
  const appliedCampaigns: PricingCampaignRow[] = [];

  for (const campaign of campaignRows) {
    if (!campaign.is_active) {
      continue;
    }

    const startsAt = campaign.starts_at == null ? null : new Date(campaign.starts_at);
    const endsAt = campaign.ends_at == null ? null : new Date(campaign.ends_at);
    if (startsAt != null && startsAt > now) {
      continue;
    }
    if (endsAt != null && endsAt < now) {
      continue;
    }
    if (Number(campaign.min_order_amount) > baseTotal) {
      continue;
    }
    if (
      campaign.applies_to_service != null &&
      campaign.applies_to_service !== 'ALL' &&
      !selectedServices.includes(campaign.applies_to_service)
    ) {
      continue;
    }

    const rawDiscount = campaign.discount_type === 'PERCENT'
      ? baseTotal * (Number(campaign.discount_value) / 100)
      : Number(campaign.discount_value);
    const remaining = Math.max(0, baseTotal - discountTotal);
    const appliedDiscount = Math.min(rawDiscount, remaining);
    if (appliedDiscount <= 0) {
      continue;
    }

    discountTotal += appliedDiscount;
    appliedCampaigns.push(campaign);
  }

  const lines: PricingQuoteResult['lines'] = [
    ...machineRows.map((row) => ({
      label: row.name,
      type: 'MACHINE' as const,
      amount: Number(row.price),
    })),
    ...enabledServiceFees.map((row) => ({
      label: row.display_name,
      type: 'SERVICE_FEE' as const,
      amount: Number(row.amount),
    })),
    ...appliedCampaigns.map((row) => ({
      label: row.name,
      type: 'DISCOUNT' as const,
      amount:
        row.discount_type === 'PERCENT'
          ? -Math.min(
              baseTotal * (Number(row.discount_value) / 100),
              baseTotal,
            )
          : -Math.min(Number(row.discount_value), baseTotal),
    })),
  ];

  return {
    machineSubtotal,
    serviceFeeTotal,
    discountTotal,
    finalTotal: Math.max(0, baseTotal - discountTotal),
    appliedCampaigns,
    lines,
  };
}