### ADR-001: Data Stores & Migrations

Context
- Postgres is source of truth; Redis for locks/cache; Mongo for layouts.

Decision
- Postgres 15 with SQL-only migrations via Umzug; schema includes `events`, `event_seats`, `orders`, `order_lines`, `stripe_events`, `order_audit_log`.
- Session timeouts at connect: `statement_timeout`, `lock_timeout`, `idle_in_transaction_session_timeout`.
- Fenced locks: bump-at-hold in Postgres; Redis holds with rollback Lua on DB failure.

Consequences
- Deterministic migrations; forward-only by default.
- Reduced deadlocks via sorted batch updates.
- Clear separation of ephemeral lock state vs durable inventory.



