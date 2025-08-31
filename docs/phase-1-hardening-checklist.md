## Phase 1 Hardening Checklist (P0 → P2)

This checklist captures what remains to reliably ship Phase 1: allow guests to browse shows/seatmaps, select seats, pay, receive tickets, and present tickets for verification. Each checkpoint has deliverables and acceptance criteria. Priorities: P0 (ship blocker), P1 (near‑term), P2 (nice‑to‑have).

### Legend
- [ ] Not started
- [~] In progress
- [x] Done

---

## P0: Must‑ship for Phase 1

- [ ] Align checkout policy: guest vs. login required
  - Summary: Decide if `POST /api/v1/orders` is guest‑friendly or requires auth, then align client and server.
  - Deliverables:
    - If guest checkout: allow unauthenticated `POST /v1/orders` with strict input validation and rate limits; ensure no user PII is logged; keep `X-Org-ID` policy enforced.
    - If auth required: gate iOS checkout behind login; ensure `/v1/users/profile` is real (no mocks) and tokens refresh properly.
    - Update API docs and iOS UX copy accordingly.
  - Acceptance:
    - End‑to‑end happy path from seat selection → payment sheet → success is possible in the chosen mode without 401/403 surprises.

- [ ] Enforce seat holds at order creation
  - Summary: Ensure seats in the order are actually held by the buyer/session and are not expired or owned by someone else.
  - Deliverables:
    - Redis/DB check inside `POST /v1/orders` verifying hold token/session for all `seat_ids` and `performance_id`.
    - Clear RFC7807 errors for conflicts/expiry (409 with stable `details.code`).
    - Metrics: counter for hold‑mismatch and expiry; trace span tagging performanceId and seatCount.
    - Unit tests for valid/invalid holds; integration test for concurrent conflict.
  - Acceptance:
    - Orders are rejected when seats are not properly held; logs/metrics emitted; tests green.

- [ ] Orders API: org scoping and client headers
  - Summary: Ensure organization scoping is consistent and easy to set from clients.
  - Deliverables:
    - iOS `ApiClient` automatically attaches `X-Org-ID` from config.
    - Optional: server derives default org in dev if header missing, but emits warning; prod requires header.
    - Contract documented in README/API docs.
  - Acceptance:
    - No 422 due to missing org in happy path; tests cover header presence.

- [ ] Stripe payment finalization → ticket issuance
  - Summary: On successful payment (webhook), transition order → issue tickets → persist and expose.
  - Deliverables:
    - Webhook validates signature, idempotently updates order status, and triggers ticket issuance.
    - Ticket artifacts saved with stable IDs and minimal metadata (orderId, performanceId, seatId, issuedAt, signature/QR payload).
    - Expose `GET /v1/orders/:id` to include ticket references or add `GET /v1/tickets?orderId=...`.
    - Metrics/traces around webhook processing and issuance latency.
  - Acceptance:
    - After real/stripe test payment, tickets are created exactly once and retrievable; retries safe; tests green.

- [ ] iOS checkout wiring (headers, errors, success data)
  - Summary: Ensure the app calls orders with the right headers, handles errors, and shows server‑backed success.
  - Deliverables:
    - `ApiClient` adds `X-Org-ID` and Authorization (if auth mode chosen) for `/v1/orders`.
    - User‑friendly error messages for seat selection, order creation, and payment failures.
    - Success screen reads server ticket data or a follow‑up fetch by orderId.
  - Acceptance:
    - Manual test: invalid email/seat conflict shows actionable error; success screen reflects server amounts and seats.

- [ ] Minimal ticket model + retrieval API
  - Summary: Provide a simple ticket representation that can be consumed by iOS and validator.
  - Deliverables:
    - Ticket DTO fields: `ticketId`, `orderId`, `seatId`, `performanceId`, `qr` (opaque), `issuedAt`.
    - `GET /v1/tickets/:id` (auth or proof‑of‑ownership) and/or `GET /v1/tickets?orderId=...`.
    - RFC7807 for not found/forbidden.
  - Acceptance:
    - iOS can fetch and render tickets post‑payment with stable IDs.

- [ ] Verification path compatibility
  - Summary: Ensure issued ticket QR payload is verifiable by validator service.
  - Deliverables:
    - Agree QR payload format (compact JSON or JWS) and signing/validation approach.
    - Validator reads the issued format; add a golden sample and regression test.
  - Acceptance:
    - Scan of a freshly issued ticket passes validation in test; negative cases rejected.

- [ ] Observability on the happy path and hot errors
  - Summary: Minimal traces/metrics/logs on order creation, webhook, issuance, verification.
  - Deliverables:
    - Structured logs include `service`, `context`, `correlationId`, `event`, and key fields.
    - Counters: `orders.created`, `payments.webhook.ok/error`, `tickets.issued`, `verify.ok/error`.
    - Histograms: `orders.latency`, `webhook.latency`.
  - Acceptance:
    - Dashboards/metrics visible; trace spans link order→webhook→issuance for a sample flow.

- [ ] Tests: unit, integration, e2e happy path
  - Summary: Solid test triangle for Phase 1.
  - Deliverables:
    - Unit tests for hold checks, RFC7807 errors, idempotency store, and DTO mapping.
    - Integration tests for `POST /v1/orders` + seat conflict and webhook finalization.
    - E2E: end‑to‑end happy path using Stripe test key; asserts tickets issued and retrievable.
  - Acceptance:
    - CI green with coverage at target; no flaky tests.

---

## P1: Near‑term follow‑ups

- [ ] PKPass wallet integration (iOS + backend)
  - Deliverables:
    - Backend pass signing endpoint or offline packager; device attaches `.pkpass` to Wallet.
    - iOS flow from success screen to “Add to Wallet”.
  - Acceptance: Sample pass added and openable on device; signature verified.

- [ ] Local ticket storage and offline readiness (iOS)
  - Deliverables:
    - Core Data (or lightweight store) for issued tickets.
    - Background sync from backend; simple conflict policy.
  - Acceptance: Tickets are viewable offline after initial fetch; basic sync works.

- [ ] UX polish for errors, empty states, and retries
  - Deliverables: Toasts/sheets for common errors; retry for temporary failures; better empty states.
  - Acceptance: Heuristic: common failure flows are understandable and recoverable without support.

- [ ] Admin/ops visibility for orders and tickets (read‑only)
  - Deliverables: Minimal list/view endpoints or console query scripts; basic filters for event/performance.
  - Acceptance: Operator can locate an order/ticket quickly in staging.

---

## P2: Nice‑to‑have improvements

- [ ] Dynamic pricing or seat tier override hooks (feature‑gated)
- [ ] Enhanced rate limits per IP/user for auth endpoints and holds
- [ ] Robust refresh token rotation and session management
- [ ] Data retention policy and GDPR erase flow for PII

---

## References and contracts to honor

- JSON uses `camelCase` everywhere.
- Errors follow RFC7807 with stable `type`, human `title`, `status`, and machine `details.code`.
- All writes accept and honor `Idempotency-Key`.
- Correlation ID is created on entry and propagated.
- Public HTTP surface under `/api/v1/...`; no breaking changes in v1.

---

## Suggested test names (Given/When/Then)

- orders.holds.conflict.returns409
- orders.guest.happyPath.createsPaymentIntent
- payments.webhook.success.issuesTicketsExactlyOnce
- tickets.get.byOrderId.returnsIssuedTickets
- verification.scan.validTicket.accepted
- verification.scan.tamperedTicket.rejected


