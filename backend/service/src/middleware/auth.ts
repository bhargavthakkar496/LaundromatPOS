import type { NextFunction, Request, Response } from 'express';

import { query } from '../db/transaction.js';
import { hashSha256Hex } from '../services/security.js';

function isPublicPath(path: string) {
  return path === '/auth/login' || path === '/health';
}

export async function authenticateRequest(
  request: Request,
  response: Response,
  next: NextFunction,
) {
  if (isPublicPath(request.path)) {
    next();
    return;
  }

  const authorization = request.header('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    response.status(401).json({
      error: 'unauthorized',
      detail: 'Missing bearer token',
    });
    return;
  }

  const accessToken = authorization.slice('Bearer '.length).trim();
  if (!accessToken) {
    response.status(401).json({
      error: 'unauthorized',
      detail: 'Empty bearer token',
    });
    return;
  }

  const tokenHash = hashSha256Hex(accessToken);
  const sessionResult = await query<{
    user_id: number;
    role: string;
  }>(
    `
      SELECT s.user_id, u.role
      FROM auth_sessions s
      JOIN users u ON u.id = s.user_id
      WHERE s.access_token_hash = $1
        AND s.revoked_at IS NULL
        AND (s.expires_at IS NULL OR s.expires_at > NOW())
        AND u.is_active = TRUE
      ORDER BY s.issued_at DESC
      LIMIT 1
    `,
    [tokenHash],
  );

  if (sessionResult.rowCount === 0) {
    response.status(401).json({
      error: 'unauthorized',
      detail: 'Invalid or expired bearer token',
    });
    return;
  }

  response.locals.authUserId = sessionResult.rows[0].user_id;
  response.locals.authRole = sessionResult.rows[0].role;
  next();
}
