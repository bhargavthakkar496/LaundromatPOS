# Backend Scaffold

This folder contains the first backend-facing scaffold for moving the app off local demo persistence.

## Files

- `postgres/schema.sql`
  PostgreSQL schema for users, auth sessions, customers, devices, machines, orders, payments, reservations, active order sessions, machine telemetry events, and audit logs.

- `api/openapi.yaml`
  API contract aligned to the current Flutter `BackendPosRepository`.

## Intended Use

1. Apply `postgres/schema.sql` to a fresh PostgreSQL database.
2. Use `api/openapi.yaml` as the implementation contract for your backend service.
3. Point Flutter at that backend with:

```bash
flutter run --dart-define=POS_USE_BACKEND=true --dart-define=POS_BACKEND_BASE_URL=https://your-api-base-url
```

For the local backend running on `localhost:8080`, use:

```bash
flutter run --dart-define=POS_USE_BACKEND=true --dart-define=POS_BACKEND_BASE_URL=http://127.0.0.1:8080
```

The backend service also includes a live PostgreSQL-backed integration suite:

```bash
cd backend/service
npm run test:integration
```

Before running the service or integration tests against an existing local database, apply any new files in `postgres/migrations` to the database referenced by `backend/service/.env`.

And the Flutter app has an opt-in backend smoke test:

```bash
cd flutter_app
flutter test test/backend_repository_e2e_test.dart --dart-define=POS_RUN_BACKEND_SMOKE=true --dart-define=POS_BACKEND_BASE_URL=http://127.0.0.1:8080
```

## Notes

- The schema includes audit- and telemetry-oriented tables even where the current Flutter app does not fully surface them yet.
- The API spec matches the endpoints currently called by `flutter_app/lib/src/data/backend_pos_repository.dart`.
- PINs and bearer tokens should always be hashed or signed server-side. The placeholder admin seed hash in the SQL file must be replaced before real use.
