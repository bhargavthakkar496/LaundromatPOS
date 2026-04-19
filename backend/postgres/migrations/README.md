# SQL Migrations

Ordered PostgreSQL migrations derived from `../schema.sql`.

Apply them in lexical order:

1. `001_extensions_and_enums.sql`
2. `002_identity_and_customer_tables.sql`
3. `003_machine_order_payment_tables.sql`
4. `004_reservations_active_sessions_events.sql`
5. `005_seed_demo_records.sql`
6. `006_seed_ironing_stations.sql`
7. `007_service_selection_support.sql`
8. `008_payment_status_refund_support.sql`
9. `009_pricing_management.sql`
10. `010_inventory_master_and_movement_history.sql`
11. `011_inventory_restock_requests.sql`
12. `012_pricing_management.sql`
13. `013_maintenance_workflow.sql`

These are intended as the starting point for a real migration tool such as:

- Flyway
- Liquibase
- dbmate
- node-pg-migrate
- Prisma migrations

The backend service integration suite runs against the database configured by `backend/service/.env`. Apply any new migrations there before running `npm run test:integration`.
