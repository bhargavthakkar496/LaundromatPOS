# Backend Service Scaffold

This is a lightweight TypeScript + Express + PostgreSQL scaffold for implementing the API defined in [../api/openapi.yaml](../api/openapi.yaml).

## Quick start

1. Copy `.env.example` to `.env`
2. Install dependencies
3. Run the SQL migrations in `../postgres/migrations`
4. Start the service

```bash
npm install
npm run dev
```

## Current structure

- `src/app.ts`
  Express app wiring
- `src/server.ts`
  Process entrypoint
- `src/config/`
  Environment configuration
- `src/db/`
  PostgreSQL pool + transaction helpers
- `src/routes/`
  Route registration by domain
- `src/controllers/`
  HTTP handlers
- `src/repositories/`
  SQL-facing repository placeholders
- `src/middleware/`
  Shared auth and request middleware
- `src/services/`
  Business service placeholders
- `src/types/`
  Shared DTOs aligned to the Flutter/OpenAPI contract

The scaffold is intentionally thin: it gives you the service boundaries and route map without pretending the endpoint logic is already done.
