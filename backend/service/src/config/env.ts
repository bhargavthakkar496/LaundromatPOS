import 'dotenv/config';

import { z } from 'zod';

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  DATABASE_URL: z.string().min(1),
  AUTH_TOKEN_TTL_MINUTES: z.coerce.number().default(480),
  WEB_ALLOWED_ORIGINS: z.string().optional(),
});

export const env = envSchema.parse(process.env);
