# Expected findings for the code-test-design fixtures

Each fixture is a small module plus its tests, with test-design gaps planted on purpose. All the tests pass today. A review with the `code-test-design` skill should find each gap below, and must not flag the clean tests.

**Matching:** a finding matches an item when its **Class** is the item's class and its **File** cites the item's file at one of the listed lines (a range counts if it overlaps). Severity is listed for reference and isn't scored. Extra findings aren't penalized unless they hit a "must not" row.

**Scoring:** `python3 tests/fixtures/code-test-design/score.py <python|javascript> <report.md>` prints each item and a score. It reads the fixed report format and checks the class and the exact `file:line`, so it's stricter than a keyword match. Still check its misses by hand: a correct finding with a mistyped field counts as a miss.

## `python/` (`pricing.py`, `test_pricing.py`)

| Class | Expected | File and lines | Severity |
| --- | --- | --- | --- |
| wrong reason | `test_save10_discount` asserts only that the result is truthy; a mutant that returns `total` unchanged still passes | `test_pricing.py:10-11` | high |
| flaky | `test_expiry` depends on the real clock and `time.sleep` | `test_pricing.py:14-17` | medium |
| untested behaviour | the `"HALF"` discount branch has no test | `pricing.py:11-12` | medium |
| missing edge case | `is_expired` at the exact deadline (`now == expires_at`) isn't tested | `pricing.py:16-18` | low |
| must not | flag `test_subtotal` or `test_not_expired_before_deadline` as wrong reason or flaky | `test_pricing.py:6-7`, `test_pricing.py:20-21` | — |

## `javascript/` (`cart.js`, `cart.test.js`)

| Class | Expected | File and lines | Severity |
| --- | --- | --- | --- |
| wrong reason | "removes an item" ignores `removeItem`'s return value and checks the input array; a mutant that returns `cart` unchanged still passes | `cart.test.js:16-19` | high |
| flaky | "cart keeps the added item" depends on the earlier test through the shared `shared` variable, so it fails when run alone or in another order | `cart.test.js:5`, `cart.test.js:7-13` | medium |
| untested behaviour | `total` has no test (it isn't even imported) | `cart.js:9-10` | medium |
| missing edge case | `shippingFee` at exactly 50 isn't tested | `cart.js:13-14`, `cart.test.js:22-25` | low |
| must not | flag the shipping test as wrong reason or flaky | `cart.test.js:22-25` | — |

**Correction after the first blind run:** this table first listed "adds an item" as a clean test. The blind run flagged it as wrong reason and proved it: with `addItem` changed to `return [item]`, all 4 tests still pass, because the test only checks the length after adding to an empty cart. That finding is correct, so the row was removed, and flagging that test is now an accepted extra finding.
