import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { env } from './config/env.js';
import { authenticateRequest } from './middleware/auth.js';
import { buildApiRouter } from './routes/index.js';

function parseAllowedOrigins() {
  const configured = env.WEB_ALLOWED_ORIGINS?.split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (configured != null && configured.length > 0) {
    return configured;
  }

  return [
    'http://localhost:3000',
    'http://localhost:5000',
    'http://localhost:50418',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5000',
    'http://127.0.0.1:50418',
  ];
}

function isLoopbackOrigin(origin: string) {
  return /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/i.test(origin);
}

export function createApp() {
  const app = express();
  const allowedOrigins = parseAllowedOrigins();

  app.use(
    cors({
      origin(
        origin: string | undefined,
        callback: (error: Error | null, allow?: boolean) => void,
      ) {
        if (
          origin == null ||
          allowedOrigins.includes(origin) ||
          isLoopbackOrigin(origin)
        ) {
          callback(null, true);
          return;
        }
        callback(new Error(`Origin not allowed by CORS: ${origin}`));
      },
      credentials: false,
    }),
  );
  app.use(helmet());
  app.use(express.json());
  app.use(morgan('dev'));
  app.use(authenticateRequest);

  app.get('/health', (_request, response) => {
    response.json({ ok: true });
  });

  app.use(buildApiRouter());

  app.use((error: unknown, _request: express.Request, response: express.Response, _next: express.NextFunction) => {
    response.status(500).json({
      error: 'internal_error',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  });

  return app;
}
