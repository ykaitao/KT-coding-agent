# Expected findings for the code-health fixtures

Each fixture plants code-health problems on purpose. A scan with the `scan-code-health` skill should find every planted problem and report nothing in the clean functions.

Match a finding by **function and problem class**. The line number is only a cross-check, since a scan of an edited or stripped copy shifts lines. Severity should match, but a one-level difference is worth a note, not a failure.

Problem classes:
- **unchecked empty input:** the function breaks or returns a wrong value on empty input.
- **swallowed error:** an error is caught and discarded, so callers can't tell failure from success.
- **drifted duplicate:** two functions repeat the same logic, and the copies already behave differently.
- **dead code:** nothing in the repo calls it.
- **shared mutable state:** a value leaks from one call into the next.

## `python/sample.py`

| Function | Problem class | Severity | Line |
| --- | --- | --- | --- |
| `average_price` | unchecked empty input: `average_price([])` raises `ZeroDivisionError` | high | 10 |
| `add_tag` | shared mutable state: the default `tags=[]` is shared across calls | high | 13 |
| `load_stock` | swallowed error: bare `except: pass` returns `None` | medium | 22 |
| `order_total` / `invoice_total` | drifted duplicate: the same loop, but only one rounds | medium | 26, 33 |
| `_legacy_total` | dead code | low | 40 |

Clean (must not be reported): `in_stock`, `restock_needed`.

## `javascript/sample.js`

| Function | Problem class | Severity | Line |
| --- | --- | --- | --- |
| `averageScore` | unchecked empty input: `averageScore([])` returns `NaN` | high | 7 |
| `loadConfig` | swallowed error: the `catch` returns `{}`, so a missing or broken file looks like an empty config | medium | 13 |
| `cartTotal` / `receiptTotal` | drifted duplicate: the same loop, but only one rounds (0.30000000000000004 vs 0.3) | medium | 18, 26 |
| `legacyDiscount` | dead code: not exported and not called | low | 34 |

Clean (must not be reported): `isEmptyCart`, `maxQty`.
