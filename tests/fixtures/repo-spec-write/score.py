#!/usr/bin/env python3
"""Rough first-pass scorer for repo-spec-write specs against EXPECTED.md.

Usage: python3 score.py <python|javascript> <spec.md>
Each item is a set of keyword patterns that must all appear in one section of the
spec. The patterns approximate meaning, so check every miss by hand before
reporting a score. Exits 0 if every item passes, 1 otherwise.
"""
import re, sys

# (kind, description, section, [patterns that must all match], must_not)
ITEMS = {
    "python": [
        ("evidence", "count > MAX_ATTEMPTS allows a 6th try, at line 17", "evidence", [r"count\s*>\s*MAX_ATTEMPTS", r":1?7\b|17"], False),
        ("evidence", "the window is unused, so lockouts never expire", "evidence", [r"WINDOW_SECONDS|window", r"never|unused|ignor|not (used|checked)"], False),
        ("evidence", "record_success does nothing", "evidence", [r"record_success", r"\bpass\b|nothing|no-op"], False),
        ("criterion", "locked after 5 failures", "criteria", [r"\b5\b|five", r"locked|reject|True"], False),
        ("criterion", "allowed again after the window", "criteria", [r"window|15 minutes|T \+", r"again|unlock|False|expire"], False),
        ("criterion", "success resets the count", "criteria", [r"success", r"reset|clear|False"], False),
        ("question", "the intended limit and window", "questions", [r"window|limit|attempts|15"], False),
        ("question", "per user or per IP, or what the user is told", "questions", [r"\bIP\b|per[- ]user|told|message|shown"], False),
        ("must not", "CAPTCHA, alerts or unlock flows as requirements", "criteria", [r"captcha|e-?mail|notif|unlock (flow|tool)"], True),
    ],
    "javascript": [
        ("evidence", "unquoted join(\",\"), at line 6", "evidence", [r"join\(\s*[\"'],[\"']\s*\)", r":6\b"], False),
        ("evidence", "an empty list returns \"\"", "evidence", [r"empty|length\s*===\s*0", r"\"\"|empty string"], False),
        ("evidence", "values follow each row's own key order", "evidence", [r"order|Object\.values"], False),
        ("criterion", "comma, quote or newline stays in one column", "criteria", [r"comma", r"quot"], False),
        ("criterion", "empty report has a header, or raised as a question", "criteria+questions", [r"empty"], False),
        ("criterion", "values under the right header with a different key order", "criteria", [r"order|header"], False),
        ("question", "line ending, empty-report columns, or target spreadsheet", "questions", [r"line ending|\\r\\n|column|spreadsheet|empty"], False),
        ("must not", "encoding, delimiter or Excel rules stated as fact", "criteria", [r"\bBOM\b|encoding|UTF-?8|Excel|semicolon"], True),
    ],
}
HEADINGS = {"evidence": "Evidence", "criteria": "Acceptance criteria", "questions": "Open questions"}

def section(text, name):
    m = re.search(r"^## " + re.escape(HEADINGS[name]) + r".*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""

def main():
    fixture, path = sys.argv[1], sys.argv[2]
    text = open(path, encoding="utf-8").read()
    passed = 0
    for kind, desc, where, patterns, must_not in ITEMS[fixture]:
        body = "".join(section(text, w) for w in where.split("+"))
        hit = all(re.search(p, body, re.I) for p in patterns)
        ok = not hit if must_not else hit
        passed += ok
        print(f"{'ok  ' if ok else 'MISS'} {kind}: {desc}")
    total = len(ITEMS[fixture])
    print(f"score: {passed}/{total} (rough; check misses by hand)")
    sys.exit(0 if passed == total else 1)

main()
