import type { Request, Response } from 'express';
import { z } from 'zod';

import { withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { generateAccessToken, hashSha256Hex, verifyPin } from '../services/security.js';
import { serializeUser } from '../services/serializers.js';

const loginSchema = z.object({
  username: z.string().trim().min(1),
  pin: z.string().trim().min(1),
});

export async function loginHandler(request: Request, response: Response) {
  const parsed = loginSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const result = await withTransaction(async (client) => {
    const userResult = await client.query<{
      id: number;
      username: string;
      display_name: string;
      pin_hash: string;
      role: string;
    }>(
      `
        SELECT id, username, display_name, pin_hash, role
        FROM users
        WHERE username = $1
          AND is_active = TRUE
        LIMIT 1
      `,
      [parsed.data.username],
    );

    if (userResult.rowCount === 0) {
      return null;
    }

    const user = userResult.rows[0];
    if (!verifyPin(parsed.data.pin, user.pin_hash)) {
      return null;
    }

    const accessToken = generateAccessToken();
    const accessTokenHash = hashSha256Hex(accessToken);
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 8);

    await client.query(
      `
        INSERT INTO auth_sessions (
          user_id,
          access_token_hash,
          issued_at,
          expires_at,
          user_agent
        ) VALUES ($1, $2, NOW(), $3, $4)
      `,
      [
        user.id,
        accessTokenHash,
        expiresAt.toISOString(),
        request.header('user-agent') ?? null,
      ],
    );

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: user.id,
      action: 'auth.login',
      entityType: 'user',
      entityId: String(user.id),
      afterState: {
        issuedAt: new Date().toISOString(),
        expiresAt: expiresAt.toISOString(),
      },
      metadata: {
        username: user.username,
      },
    });

    return {
      accessToken,
      refreshToken: null,
      expiresAt: expiresAt.toISOString(),
      user: serializeUser(user),
    };
  });

  if (result == null) {
    response.status(401).json({
      error: 'invalid_credentials',
      detail: 'Username or PIN is incorrect',
    });
    return;
  }

  response.json(result);
}
