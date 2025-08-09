Property tests:
- Generate N contenders over M seats; assert zero oversell across runs.
- ABA safety on extend/release with expectedVersion.
- TTL expiry frees seats and prohibits stale extends.
Data shapes documented; seeded RNG for determinism.
