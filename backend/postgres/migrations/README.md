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

These are intended as the starting point for a real migration tool such as:

- Flyway
- Liquibase
- dbmate
- node-pg-migrate
- Prisma migrations
