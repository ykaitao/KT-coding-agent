#!/usr/bin/env python3
"""Scores a code-test-design report against EXPECTED.md.

Usage: python3 score.py <python|javascript> <report.md>
A finding matches an expected item when its Class field is the item's class and its
File field cites the item's file at a listed line (a cited range counts if it
overlaps). Exits 0 if every item passes, 1 otherwise.
"""
import re, sys

# (class, description, [(file, first_line, last_line), ...])
EXPECTED = {
    "python": [
        ("wrong reason", "test_save10_discount asserts only truthiness", [("test_pricing.py", 10, 11)]),
        ("flaky", "test_expiry uses the real clock and sleep", [("test_pricing.py", 14, 17)]),
        ("untested behaviour", "the HALF branch has no test", [("pricing.py", 11, 12)]),
        ("missing edge case", "is_expired at the exact deadline", [("pricing.py", 16, 18)]),
    ],
    "javascript": [
        ("wrong reason", "removes an item ignores the return value", [("cart.test.js", 16, 19)]),
        ("flaky", "cart keeps the added item depends on the earlier test", [("cart.test.js", 5, 5), ("cart.test.js", 7, 13)]),
        ("untested behaviour", "total has no test", [("cart.js", 9, 10)]),
        ("missing edge case", "shippingFee at exactly 50", [("cart.js", 13, 14), ("cart.test.js", 22, 25)]),
    ],
}
# (classes that must not be used, description, [(file, first_line, last_line)])
MUST_NOT = {
    "python": [
        ({"wrong reason", "flaky"}, "clean tests test_subtotal and test_not_expired_before_deadline",
         [("test_pricing.py", 6, 7), ("test_pricing.py", 20, 21)]),
    ],
    "javascript": [
        ({"wrong reason", "flaky"}, "the clean shipping test", [("cart.test.js", 22, 25)]),
    ],
}

def findings(text):
    """(class, file, first, last) for each ### finding in the fixed report format."""
    out = []
    for block in re.split(r"^### ", text, flags=re.M)[1:]:
        cls = re.search(r"^- \*\*Class:\*\*\s*(.+)$", block, re.M)
        cls = cls.group(1).strip().strip("`").lower().replace("behavior", "behaviour") if cls else ""
        file_line = re.search(r"^- \*\*File:\*\*(.+)$", block, re.M)
        for f, a, b in re.findall(r"`?([\w./-]+):(\d+)(?:-(\d+))?`?", file_line.group(1) if file_line else ""):
            out.append((cls, f.rsplit("/", 1)[-1], int(a), int(b or a)))
    return out

def hits(found, classes, places):
    return [x for x in found if x[0] in classes and any(
        x[1] == f and x[2] <= last and x[3] >= first for f, first, last in places)]

def main():
    fixture, path = sys.argv[1], sys.argv[2]
    found = findings(open(path, encoding="utf-8").read())
    score = total = 0
    for cls, desc, places in EXPECTED[fixture]:
        total += 1
        ok = bool(hits(found, {cls}, places))
        score += ok
        print(f"{'ok  ' if ok else 'MISS'} {cls}: {desc}")
    for classes, desc, places in MUST_NOT[fixture]:
        total += 1
        bad = hits(found, classes, places)
        score += not bad
        print(f"{'ok  ' if not bad else 'FAIL'} must not flag {desc}" + (f" (flagged: {bad})" if bad else ""))
    print(f"findings parsed: {len(found)}; score: {score}/{total}")
    sys.exit(0 if score == total else 1)

main()
