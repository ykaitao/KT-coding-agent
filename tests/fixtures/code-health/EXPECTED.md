# Expected findings for `inventory.py`

This fixture has 5 planted code-health problems. A scan of `tests/fixtures/code-health/inventory.py` with the `scan-code-health` skill should find each of them and nothing in the two clean functions at the end.

| # | Line | Severity | Problem |
| --- | --- | --- | --- |
| 1 | 10 | high | `average_price([])` divides by zero: no empty-input check. |
| 2 | 13 | high | `add_tag` uses a mutable default `tags=[]`, so tags from one call leak into the next. |
| 3 | 22 | medium | `load_stock` swallows every error with a bare `except: pass` and returns `None`. |
| 4 | 26, 33 | medium | `order_total` and `invoice_total` duplicate the same loop and have already drifted apart (only one rounds). |
| 5 | 40 | low | `_legacy_total` is dead code: nothing in the repo calls it. |

Not problems (false-positive traps): `in_stock` (line 44) and `restock_needed` (line 48) are correct.
