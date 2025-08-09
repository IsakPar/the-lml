Integration (Testcontainers):
- Services: Redis + Postgres. Run redis scripts and append shadow events.
- Assert idempotency effects across retries (platform-level), shadow append correctness, and RLS enforcement via app.tenant_id.
