# shop-checkout

A small, synthetic checkout service used for a product test. Nothing here runs in production.

- `lib/cart/lock.ts`: the lock taken around cart finalisation (a Postgres advisory lock, three retries with
  jitter, a five-second timeout).
- `lib/cart/finalise.ts`: finalises a cart inside one transaction.
- `lib/cart/total.ts`: cart totals in integer cents.

`.stranger/` holds recorded agent sessions of this repository for the test. `sh .stranger/seed.sh` places them
where the agents keep their history for this clone; `sh .stranger/seed.sh --cleanup` removes exactly those files.
