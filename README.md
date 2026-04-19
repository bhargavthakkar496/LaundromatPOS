
# WashPOS – SUNMI D3 PRO
WashPOS is a dual-screen laundry point-of-sale demo focused on operator checkout, customer self-service, and machine lifecycle visibility.

- Main screen: operator workflow, machine operations, orders, and customer lookup
- Customer screen (10.1"): confirmation, payment, and live order visibility

The repo still contains the original Android/Kotlin shell for the SUNMI D3 PRO direction, but the active product implementation is now in `flutter_app/`.

## Product Overview

Today, the project demonstrates a laundromat operating flow that includes:

- staff sign-in and persisted manager session
- machine overview with live status transitions
- operator-side order booking and checkout
- customer-facing confirmation and payment flow
- receipt generation and WhatsApp notifications
- customer lookup, onboarding, and order history

The current implementation is best understood as a polished product demo with working end-to-end flows, local persistence, and a growing operations surface for cashier and manager use cases.

## Project Status

The repo currently has two tracks:

- `app/`: Android/Kotlin project structure and resources for the original SUNMI D3 PRO direction
- `flutter_app/`: the primary implementation path for new product features and the most complete demo flow in the repo today

### Current Capabilities In Flutter

The Flutter app now covers a broader demo workflow than the original starter flow.

- Staff login with persisted manager session using demo credentials: `admin / 1234`
- Manager dashboard with entry points for machine operations, orders, customer lookup, inventory, customer screen, and reporting-oriented history views
- Live machine overview with availability, in-use, ready-for-pickup, and maintenance states
- POS checkout flow with customer capture, simulated payment, paid order creation, and order history updates
- Receipt actions including WhatsApp receipt sharing and print-slip generation
- Customer lookup and onboarding with saved preferences, visit history, spend totals, favorite machines, and upcoming reservations display
- Operator-managed order booking flow with shared active order session across operator and customer screens
- Customer self-service screen for confirmation and payment in kiosk-style or customer-display scenarios
- WhatsApp deep-link notifications for payment success, cycle completion, machine delay, and refund confirmation
- Seeded demo data with persisted local state using shared preferences for customers, orders, machines, reservations, active order session, and manager session
- Basic automated test coverage for login rendering and operator/customer payment state synchronization

### Implemented But Still Demo-Grade

The current Flutter app is usable as a product demo, but several parts are still mocked or partially scaffolded.

- Payments are simulated rather than connected to a real gateway
- Machine state changes are driven by local timing logic rather than device telemetry or machine integrations
- Inventory is a seeded browsing experience, not a transactional stock module
- Some manager dashboard entries are placeholders or route to shared history flows instead of dedicated modules
- Reservation support exists in the repository layer, but there is not yet a full reservation UI

## Android Build Setup

This repo now includes:

- Root Gradle settings in `settings.gradle.kts`
- Root plugin config in `build.gradle.kts`
- App module config in `app/build.gradle.kts`
- Android manifest, layouts, strings, and theme resources

## Open In Android Studio

1. Open the repo root in Android Studio.
2. Let Android Studio create or update `local.properties` with your Android SDK path.
3. Sync the Gradle project.
4. Run the `app` configuration on an emulator or device.

## Note About Gradle Wrapper

The Gradle wrapper files were not generated in this environment because the `gradle` command is not installed here. Android Studio should still be able to import and sync the project using the checked-in Gradle build files.

## Flutter App

The parallel Flutter app in `flutter_app/` is now the main place where product features are being implemented.

### Run The Flutter Scaffold

1. Install Flutter locally if needed.
2. From `flutter_app/`, run `flutter pub get`.
3. Start it with `flutter run`.

The Flutter app seeds demo data on first launch and then persists local state with shared preferences so flows can be exercised across restarts.

This lets the team iterate on UI, operator workflows, and customer-facing flows before deciding whether to:

- keep the existing Android/Kotlin app as the production client
- migrate feature-by-feature into Flutter
- embed Flutter into the current Kotlin Android shell

## Flutter-First Direction

Going forward, new product features should be implemented in `flutter_app/` first.

The first customer-facing Flutter feature now includes self-service machine selection and payment, designed for a customer mobile app or kiosk-style experience.

## Roadmap

The most valuable next steps are the ones that move the project from a polished demo into a production-ready POS platform.

### Near-Term Enhancements

- Replace simulated payments with a real payment gateway and reconciliation flow
- Add dedicated modules for staff, pricing, maintenance, and revenue/day-end instead of placeholder dashboard actions
- Build a full reservation UI on top of the existing repository support for reservable machines and booking conflicts
- Expand complaint and refund handling with reason capture, approval states, and support notes
- Turn inventory into a real stock workflow with edits, low-stock alerts, usage tracking, and reorder support

### Production Readiness

- Move persistence from local shared preferences to a backend-backed data model with authentication and audit history
- Integrate machine telemetry, device events, or SUNMI hardware workflows instead of relying on timer-driven demo state
- Add role-based access for cashier, manager, technician, and support users
- Strengthen reporting with revenue, utilization, refunds, customer retention, and day-end exports
- Harden the dual-screen and kiosk path for the target hardware, including printer and device integration
- Expand automated coverage with repository tests, widget tests for checkout and self-service flows, and integration tests for the end-to-end order journey
