import type { PoolClient } from 'pg';

type AuditActorType = 'USER' | 'SYSTEM' | 'DEVICE' | 'CUSTOMER';

interface WriteAuditLogInput {
  actorType: AuditActorType;
  actorUserId?: number | null;
  actorDeviceId?: number | null;
  action: string;
  entityType: string;
  entityId: string;
  requestId?: string | null;
  beforeState?: unknown;
  afterState?: unknown;
  metadata?: Record<string, unknown>;
}

interface Queryable {
  query: PoolClient['query'];
}

export async function writeAuditLog(
  db: Queryable,
  input: WriteAuditLogInput,
) {
  await db.query(
    `
      INSERT INTO audit_logs (
        actor_type,
        actor_user_id,
        actor_device_id,
        action,
        entity_type,
        entity_id,
        request_id,
        before_state,
        after_state,
        metadata
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
    `,
    [
      input.actorType,
      input.actorUserId ?? null,
      input.actorDeviceId ?? null,
      input.action,
      input.entityType,
      input.entityId,
      input.requestId ?? null,
      input.beforeState == null ? null : JSON.stringify(input.beforeState),
      input.afterState == null ? null : JSON.stringify(input.afterState),
      JSON.stringify(input.metadata ?? {}),
    ],
  );
}
