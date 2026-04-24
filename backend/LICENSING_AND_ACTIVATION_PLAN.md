# Licensing And Activation Plan

This plan turns the current laundromat POS into a licensed, store-bound product rather than a freely installable desktop app.

It is written against the current repo shape:

- Flutter desktop/mobile client in `flutter_app/`
- PostgreSQL-backed backend scaffold in `backend/`
- current auth flow in `backend/service/src/controllers/auth.controller.ts`
- current bearer middleware in `backend/service/src/middleware/auth.ts`
- current device table in `backend/postgres/schema.sql`

The target outcome is:

1. A production build cannot run meaningful POS flows without backend activation.
2. Each install belongs to exactly one store tenant.
3. Each Windows POS machine must be activated as an approved device.
4. Licenses can be suspended, expired, or revoked centrally.
5. Demo/dev mode stays available for internal development only.

## Current Gaps

- The Flutter app can run in local demo mode when backend flags are absent.
- The login screen seeds `admin / 1234` by default in `flutter_app/lib/src/screens/login_screen.dart`.
- `users`, `auth_sessions`, and `devices` exist, but there is no store tenant ownership or license enforcement.
- The current auth middleware validates bearer tokens only. It does not validate tenant entitlement or activated device state.
- The app has no activation step before login.

## Delivery Model

Use a backend-enforced licensing model, not a purely local license file.

Production requirements:

- `release` builds require `POS_USE_BACKEND=true`
- backend must return store, license, and device entitlement data
- the app must activate once per machine before login is allowed
- every authenticated request must be scoped to a store and device

Dev requirements:

- `debug` and internal QA may still use demo mode
- demo mode must be impossible to access accidentally in release builds

## Phase 1: Schema Changes

Add tenant and licensing entities on top of the existing `users`, `auth_sessions`, and `devices` tables.

### New Tables

1. `stores`
- `id BIGSERIAL PRIMARY KEY`
- `store_code TEXT NOT NULL UNIQUE`
- `store_name TEXT NOT NULL`
- `legal_name TEXT`
- `status TEXT NOT NULL DEFAULT 'ACTIVE'`
- `timezone TEXT`
- `metadata JSONB NOT NULL DEFAULT '{}'::JSONB`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`

2. `store_users`
- `store_id BIGINT NOT NULL REFERENCES stores(id)`
- `user_id BIGINT NOT NULL REFERENCES users(id)`
- `role_override user_role`
- `is_active BOOLEAN NOT NULL DEFAULT TRUE`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- unique index on `(store_id, user_id)`

3. `licenses`
- `id BIGSERIAL PRIMARY KEY`
- `store_id BIGINT NOT NULL REFERENCES stores(id)`
- `license_key_hash TEXT NOT NULL UNIQUE`
- `plan_code TEXT NOT NULL`
- `status TEXT NOT NULL`
- `device_limit INTEGER NOT NULL DEFAULT 1`
- `starts_at TIMESTAMPTZ`
- `expires_at TIMESTAMPTZ`
- `grace_ends_at TIMESTAMPTZ`
- `last_validated_at TIMESTAMPTZ`
- `metadata JSONB NOT NULL DEFAULT '{}'::JSONB`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`

4. `device_activations`
- `id BIGSERIAL PRIMARY KEY`
- `store_id BIGINT NOT NULL REFERENCES stores(id)`
- `license_id BIGINT NOT NULL REFERENCES licenses(id)`
- `device_id BIGINT NOT NULL REFERENCES devices(id)`
- `activation_code_hash TEXT`
- `activation_token_hash TEXT NOT NULL`
- `status TEXT NOT NULL DEFAULT 'ACTIVE'`
- `activated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- `last_seen_at TIMESTAMPTZ`
- `revoked_at TIMESTAMPTZ`
- `revoked_reason TEXT`
- `metadata JSONB NOT NULL DEFAULT '{}'::JSONB`
- unique active activation per `(store_id, device_id)`

5. `activation_codes`
- `id BIGSERIAL PRIMARY KEY`
- `store_id BIGINT NOT NULL REFERENCES stores(id)`
- `license_id BIGINT NOT NULL REFERENCES licenses(id)`
- `code_hash TEXT NOT NULL UNIQUE`
- `max_uses INTEGER NOT NULL DEFAULT 1`
- `used_count INTEGER NOT NULL DEFAULT 0`
- `expires_at TIMESTAMPTZ`
- `revoked_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### Existing Table Changes

1. `devices`
- keep existing table
- add `store_id BIGINT REFERENCES stores(id)`
- add `fingerprint_hash TEXT`
- add `install_id TEXT`
- add `bound_at TIMESTAMPTZ`
- add unique index on `fingerprint_hash` when not null

2. `auth_sessions`
- add `store_id BIGINT NOT NULL REFERENCES stores(id)`
- add `device_id BIGINT REFERENCES devices(id)`
- add `device_activation_id BIGINT REFERENCES device_activations(id)`

3. Domain tables

Every business entity that should be tenant-isolated must carry `store_id`.

Add `store_id BIGINT NOT NULL REFERENCES stores(id)` to:

- `customers`
- `machines`
- `orders`
- `payments`
- `payment_sessions`
- `machine_reservations`
- `active_order_sessions`
- `refund_requests`
- `maintenance_records`
- `audit_logs`
- `machine_events`

### Data Access Rule

All repository queries must include `store_id = currentStoreId`.

This is the core control that stops Store A from using Store B’s data even if binaries are copied around.

## Phase 2: Backend Contract Changes

Add activation and license status endpoints before tightening the auth flow.

### New Endpoints

1. `POST /device/preflight`

Purpose:
- tell the app whether it is already activated
- return store binding if the device is known

Request:
- `installId`
- `fingerprint`
- `deviceName`
- `deviceType`
- `platform`
- `appVersion`

Response:
- `status`: `UNACTIVATED | ACTIVATED | REVOKED | LICENSE_EXPIRED`
- optional `store`
- optional `activationChallenge`

2. `POST /device/activate`

Purpose:
- bind a machine install to a paid store license

Request:
- `activationCode`
- `installId`
- `fingerprint`
- `deviceName`
- `deviceType`
- `platform`
- `appVersion`

Response:
- `deviceActivationToken`
- `deviceActivationExpiresAt`
- `store`
- `license`
- `features`

3. `GET /license/status`

Purpose:
- let the client periodically revalidate entitlement

Headers:
- bearer user token
- device activation token

Response:
- `store`
- `licenseStatus`
- `deviceStatus`
- `features`
- `nextValidationAt`

4. `POST /device/heartbeat`

Purpose:
- update `last_seen_at`
- support revocation and concurrency rules

5. `POST /device/deactivate`

Purpose:
- cleanly retire or replace a POS terminal

### Existing Endpoint Changes

1. `POST /auth/login`

Add required fields:
- `storeCode`
- `installId`
- `deviceActivationToken`

New flow:
1. Validate store exists and is active.
2. Validate license for store is active or in grace period.
3. Validate device activation token belongs to this store and device.
4. Validate username/PIN.
5. Create `auth_sessions` row with `store_id`, `device_id`, `device_activation_id`.
6. Return session plus store/license summary.

2. All protected endpoints

Middleware must validate:
- bearer token is valid
- store is active
- license is not suspended or expired beyond grace
- device activation is still active
- session store/device matches request store/device

### Middleware Refactor

Extend `backend/service/src/middleware/auth.ts` to populate:

- `response.locals.authUserId`
- `response.locals.authRole`
- `response.locals.authStoreId`
- `response.locals.authDeviceId`
- `response.locals.authDeviceActivationId`

Then every controller/repository query must use `authStoreId`.

## Phase 3: Flutter Activation Flow

Add a mandatory activation gate before the login screen for production mode.

### New Client Services

Create:

- `flutter_app/lib/src/services/activation_service.dart`
- `flutter_app/lib/src/services/device_identity_service.dart`
- `flutter_app/lib/src/models/device_activation.dart`

Responsibilities:

1. `DeviceIdentityService`
- generate stable `installId`
- collect machine name/platform/app version
- derive a conservative device fingerprint
- persist install identity locally

2. `ActivationService`
- call `/device/preflight`
- submit activation code to `/device/activate`
- persist activation token and store binding
- expose `license/status` refresh

### New Local Persistence

Extend `SessionStore` or add `ActivationStore` for:

- `installId`
- `storeCode`
- `storeName`
- `deviceId`
- `deviceActivationToken`
- `deviceActivationExpiresAt`
- `lastLicenseValidationAt`
- `licenseStatus`

### New Screens

1. `ActivationScreen`
- shown first in production if device is not activated
- fields:
  - store code
  - activation code
  - optional device label override
- actions:
  - activate
  - retry connectivity

2. `LicenseBlockedScreen`
- shown if:
  - store suspended
  - license expired
  - device revoked

### App Startup Flow

Replace the current startup decision in `flutter_app/lib/main.dart` with:

1. Initialize bindings.
2. Load release/dev mode flags.
3. If production mode:
  - require backend config
  - load activation state
  - run `/device/preflight`
  - show `ActivationScreen` if needed
  - otherwise continue to login
4. If dev mode:
  - allow demo repository or backend repository

### Login Flow Changes

Update `flutter_app/lib/src/screens/login_screen.dart`:

- remove default username and pin in production
- include store/device activation context in login request
- display store name on the login screen once activated

## Phase 4: Release Vs Dev Split

This is the step that stops “everyone can install it and use it”.

### New Build Flags

Add explicit app mode flags:

- `POS_APP_MODE=dev`
- `POS_APP_MODE=staging`
- `POS_APP_MODE=production`

Add helper in Flutter:
- `app_build_mode.dart`

Behavior:

1. `dev`
- demo repository allowed
- seeded credentials allowed
- activation bypass allowed

2. `staging`
- backend required
- activation required
- optional debug diagnostics allowed

3. `production`
- backend required
- activation required
- demo mode disabled
- no seeded credentials
- additional license heartbeat enforced

### Concrete Flutter Changes

1. `main.dart`
- block `DemoPosRepository` in production mode

2. `login_screen.dart`
- no default `admin / 1234` in production

3. `README` and run scripts
- split dev instructions from production packaging instructions

4. Optional UI indicator
- show `storeName`
- show `deviceName`
- show `license status` in settings/about screen

## Phase 5: Operational Controls

These are backend/admin capabilities you need so sales and support can manage installs.

### Admin Actions

Implement service/admin endpoints or internal tooling for:

- create store
- issue license
- set device limit
- generate activation code
- revoke activation code
- revoke device
- suspend store
- extend expiry / grace period
- reset a machine activation during hardware replacement

### Suggested Admin Tables/Actions

- `store.create`
- `license.issue`
- `license.suspend`
- `device.activate`
- `device.revoke`
- `activation_code.issue`
- `activation_code.revoke`

All of these should write to `audit_logs`.

## Phase 6: Security Hardening

These items are not substitutes for backend licensing, but they reduce abuse.

### Backend

- hash activation codes
- hash device activation tokens if stored long term
- sign short-lived access tokens server-side
- rate-limit activation and login endpoints
- add device fingerprint mismatch alerts
- reject stale client versions if required

### Flutter/Windows

- use release builds only for customer deployment
- enable Dart obfuscation for release packaging
- code-sign the Windows executable
- do not ship demo assets, seeded users, or internal toggles in production

## Recommended Rollout Order

### Step 1
- add store/license/device activation schema
- backfill `store_id` onto business tables

### Step 2
- add backend activation endpoints
- extend auth middleware with store/device validation

### Step 3
- add Flutter activation flow and activation persistence

### Step 4
- split release/dev behavior
- disable demo mode in production

### Step 5
- add admin operations for issuing/revoking licenses and devices

## Suggested Repo Changes

### Backend

- add migration: `014_store_tenant_and_licensing.sql`
- add controller: `device_activation.controller.ts`
- add routes: `device_activation.routes.ts`
- add service: `license.service.ts`
- add repository logic for tenant-scoped queries
- update `auth.controller.ts`
- update `middleware/auth.ts`
- update `api/openapi.yaml`
- update `IMPLEMENTATION_PLAN.md`

### Flutter

- add `models/device_activation.dart`
- add `services/device_identity_service.dart`
- add `services/activation_service.dart`
- add `services/app_build_mode.dart`
- add `screens/activation_screen.dart`
- add `screens/license_blocked_screen.dart`
- update `main.dart`
- update `login_screen.dart`
- update `backend_api_client.dart` to send activation context
- extend `session_store.dart` or add `activation_store.dart`

## Acceptance Criteria

The implementation is complete when all of the following are true:

1. A production Windows install cannot reach the login screen unless the device is activated.
2. A copied production build without activation shows the activation gate instead of demo mode.
3. A suspended or expired store license blocks new sessions and surfaces a clear blocked screen.
4. Every protected backend request is scoped by `store_id`.
5. A revoked device can no longer authenticate even if user credentials are valid.
6. Dev builds still support local demo mode for internal development.

## Non-Goals

This plan does not attempt to make the desktop binary impossible to copy.

That is not realistic for a local app. The actual protection comes from:

- tenant-scoped backend data
- device activation
- store license enforcement
- production builds that do not run useful workflows offline
