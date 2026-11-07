---
name: system-design-review
description: Check a design or change that touches persistent data against principles for ownership and access, transactions, audit, database constraints, migrations, caches and offline copies, and cost and money bounds. Use when designing or reviewing schema, write paths, migrations, sync or caching, or anything that stores money, permissions or user data.
---

# System design review

Use these as questions to ask of a design or a diff that touches stored data. The examples use a made-up service with `accounts`, `orders` and `payments`. Translate them to the system in front of you, and skip sections that don't apply (not every system has tenants, money or offline clients).

For a review, name each principle a change breaks, with the scenario that breaks it. For a design, say which ones it relies on.

## Ownership and access

- Every record has an owner, and access is checked against that owner on every path: the main row and also its joins, lists, search, counts, exports and files. An order list filtered by account but joined to unfiltered payments still leaks.
- An id sent by the client is a request, not proof of access. Load the record, check its owner, and answer "not found" and "not allowed" identically, so callers can't probe which ids exist.
- Check permission before taking a lock. Otherwise any caller can block someone else's record.
- Unknown values fail closed: a role the code doesn't recognize grants nothing, and a status it doesn't recognize isn't treated as active.
- Keep one writable source for each fact. A copy kept for compatibility is read-only and has a removal date.
- Numbers shown to users (order numbers, invoice numbers) are allocated per owner, not taken from the global primary key, which reveals volume and leaves gaps.
- A store that clients write directly (a document database with access rules, an object bucket) needs an explicit contract: who may write which fields, with what types and size limits, and what an allowed or refused request tells the caller about other records.

## Writes as whole transactions

- Trace each write from the request to the commit and the next read. Check the session settings production really uses (autoflush, isolation level). A test with different settings can pass while production drops a change.
- Serialize competing writers before deciding anything that depends on current state, and re-check permissions after acquiring the lock if they can change concurrently.
- One business operation is one transaction: the order update, its audit row, its ledger entry and the balance change commit or roll back together.
- Model status as allowed transitions. Correct mistakes by appending a compensating record (a refund, a reversal), not by rewriting history.
- Retries are idempotent: the same request key with the same payload returns the first result, and with a different payload it is rejected.
- When a refund returns something that expires (store credit, a voucher), put it into a new linked lot with its own expiry. Reviving a lot whose expiry has passed silently destroys the refund.
- Background writers of a cache or local copy compare a version or timestamp before replacing a row, or a slow sync brings back a record that was just deleted.
- A resumable draft saves the server ids it has already created, so finishing after a reload doesn't create a duplicate order.
- Take sync cursors from data the server returned, not from the client's clock.
- Keep fan-out within platform limits: concurrent reads, batch sizes and quotas.
- Run data repairs to completion and make them idempotent. Don't run them fire-and-forget at startup, where they race the UI.
- A list that authorizes deletion ("these files are unreferenced") is treated as incomplete until proven complete. Give it a size cap with an overflow flag, and have every consumer treat "unknown" as "keep".

## Identity and audit

- Record who made a change by stable user id, never by an email address or other contact detail, which can change hands. Store the display name as it was at the time.
- Commit the audit row atomically with the change it records, and give owners a readable screen for it. An audit log nobody can read doesn't help anyone.
- Logging out must end the session server-side, e.g. by incrementing a session version stored on the user. "Sign out everywhere" asks for a recent login and is audited.
- Don't return other users' login identifiers in ordinary responses. Show a masked label instead.

## Invariants in the database

- Validation in the API isn't an invariant, because scripts, repairs and migrations skip it. Put allowed values, ranges and same-owner references into the schema: table constraints for values and ranges, multi-column foreign keys for same-owner links.
- Build the list of allowed values from every real writer and client payload, not from test fixtures. Before adding a constraint, run a read-only query on a copy of production that lists the rows that would violate it.
- Test each constraint by breaking only that rule. A test row that also has a missing parent fails on the foreign key and proves nothing about the CHECK.
- A new allowed value can't reach production before the constraint that permits it.

## Migrations

- Use ordered migrations with a single runner. Each starts with a read-only preflight that names the offending table and rows, and it stops instead of guessing when data is ambiguous.
- Rebuild tables atomically, keeping ids, indexes, constraints and foreign-key behavior. Backfill and verify the new shape before dropping the old one. Make interrupted runs safe to resume.
- All branches draw migration version ids from one sequence. Before merging, look for the same id on other open branches, and leave already-applied ids alone forever.
- Run every migration, starting from the oldest version you support and again from one in the middle, twice each, then diff the resulting schema against the models.
- Backfill with set-based statements, not a query per row. Check that the production database version supports every feature used.
- Change storage models in stages: introduce the new model, dual-write, backfill and check, move readers over, and only then delete the old model.

## Caches, mirrors and offline copies

- Propagate deletes as tombstones with a fresh timestamp, so incremental sync can remove local copies.
- A cache that can't prove it's complete doesn't stand in for the server. "Recently synced" isn't the same as "complete": enumerate everything that writes locally, and invalidate once each write has finished, whether it succeeded or failed.
- An id the local copy doesn't know is unknown, not orphaned. Don't delete things because of it.
- Signing out clears every local store, not just one.
- With pagination, decide whether search, sort, filters and counts apply to what's loaded or to everything, and tell the user which.
- Cache keys, hashes and normalization (case, language, script) come from a single shared function that both writers and readers call, with a parity test. When a normalization change alters stored keys, plan a backfill. When one source's semantics change, version only that source's keys.

## Bounds, cost and money

- A limit must hold on every route into the same expense: the server path, the client-parsed path, retries and imports. If users can create things that cost money to process, cap how many each user may create.
- Store money as integers in minor units (cents). Reject precision you can't represent instead of rounding silently, and apply the same rule to refunds, allocations and reports.
- Bound every list. Cursors are tied to their filter and owner, ordering is stable, and indexes match the measured queries.
- A read for one record is scoped to that record. Don't compute an aggregate for a whole account and filter it afterwards. Avoid joins with no equality key.
- Keep the database's query-planner statistics fresh, and measure the heavy queries before and after a change.
- Treat "now" as an input. A value recomputed at read time and checked against a stored one must not change just because the business day rolled over or a release shipped.
- Rate limits keep a counter per user, written transactionally. The counters expire, and they're charged for the work actually returned.
- Before optimizing cost, name what actually sets the floor and measure the expected gain. If you can't measure it yet, add the measurement first.
- Telemetry is opt-in, allowlisted and pseudonymous, carries no user content, and never fails the request.
- In tests, assert the committed state after a fresh read, including partial, repeated, reversed and failed operations.
