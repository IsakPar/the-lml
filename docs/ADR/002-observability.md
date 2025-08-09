### ADR-002: Observability Defaults

Context
- Reliability during on-sales requires actionable telemetry.

Decision
- Prometheus metrics with singleton Registry to avoid duplicate registrations.
- OpenTelemetry tracing; AsyncLocalStorage binds correlationId to active span.
- Structured logs include `service`, `context`, `correlationId`, `trace_id`, `span_id`, `event`, `severity`.
- SLOs: p99 hold ≤150ms; p99 create order ≤600ms (server time); p99 webhook→confirmed ≤2s.

Consequences
- Per-route latency histograms and error counters guide budgets.
- 409 conflicts (stale lock, rate-limit) tracked explicitly.



