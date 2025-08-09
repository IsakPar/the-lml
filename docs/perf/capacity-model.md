# Tier A/B perf targets
Tier A: CDN reads 50k–100k rps; API overlay p95 < 150ms; writes 5k–10k orders/min burst; inventory p99 acquire < 80ms @1k contenders/500 seats.
Tier B: waiting room, bot mitigation, Redis Cluster, PG partitioning (backlog).
Tests: k6 scenarios + integration suites to prove targets.
