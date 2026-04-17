import type { Response } from 'express';

export function sendNotImplemented(
  response: Response,
  scope: string,
  details?: Record<string, unknown>,
) {
  response.status(501).json({
    error: 'not_implemented',
    scope,
    details: details ?? {},
  });
}
