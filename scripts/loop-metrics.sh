#!/usr/bin/env bash
# Loop metrics for PRs merged in a date window, as a Markdown table.
# Usage: scripts/loop-metrics.sh <owner/repo> <since> <until>
#   since/until are dates (YYYY-MM-DD, inclusive) compared with each PR's merge date.
# Needs gh (authenticated) and python3. Definitions are in docs/MEASURING.md.
# Every GitHub read is its own `gh api --paginate <path>` call with no other
# flags, so the review-event guard hook never sees a chained reviews read.
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 <owner/repo> <since YYYY-MM-DD> <until YYYY-MM-DD>" >&2
  exit 2
fi

python3 - "$1" "$2" "$3" <<'PY'
import json, re, subprocess, sys
from datetime import datetime

repo, since, until = sys.argv[1:4]

def api(path):
    """One standalone read: gh api --paginate <path>. Returns a list or dict."""
    out = subprocess.run(["gh", "api", "--paginate", path],
                         check=True, capture_output=True, text=True).stdout
    # --paginate prints one JSON document per page; decode them in turn.
    dec, pos, pages = json.JSONDecoder(), 0, []
    while True:
        while pos < len(out) and out[pos].isspace():
            pos += 1
        if pos >= len(out):
            break
        doc, pos = dec.raw_decode(out, pos)
        pages.append(doc)
    if not pages:
        return []
    if isinstance(pages[0], list):
        return [item for page in pages for item in page]
    return pages[0]

def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")

# Merged PRs in the window (the pulls list is newest-first by default; read all closed).
pulls = [p for p in api("repos/%s/pulls?state=closed&per_page=100" % repo)
         if p.get("merged_at") and since <= p["merged_at"][:10] <= until]
pulls.sort(key=lambda p: p["number"])

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", re.M)
BYPASS = re.compile(r"\bexits? 0\b|I ran the hook|bypass(ed)?\b.*\b(reproduc|exit)", re.I)
commit_files = {}

def files_of(sha):
    if sha not in commit_files:
        commit_files[sha] = api("repos/%s/commits/%s" % (repo, sha)).get("files", [])
    return commit_files[sha]

def led_to_change(c, commits):
    """A later commit on the PR touches the comment's file at or near its line."""
    line = c.get("original_line") or c.get("line")
    if not line:
        return False
    for k in commits:
        if ts(k["commit"]["committer"]["date"]) <= ts(c["created_at"]):
            continue
        for f in files_of(k["sha"]):
            if f.get("filename") != c["path"]:
                continue
            patch = f.get("patch")
            if patch is None:          # binary or too large: the file changed
                return True
            for m in HUNK.finditer(patch):
                start, length = int(m.group(1)), int(m.group(2) or 1)
                if start - 3 <= line <= start + length + 3:
                    return True
    return False

rows = []
for p in pulls:
    n = p["number"]
    reviews = api("repos/%s/pulls/%d/reviews" % (repo, n))
    comments = api("repos/%s/pulls/%d/comments" % (repo, n))
    commits = api("repos/%s/pulls/%d/commits" % (repo, n))
    top = [c for c in comments if not c.get("in_reply_to_id")]
    per_review = {}
    for c in top:
        per_review.setdefault(c.get("pull_request_review_id"), []).append(c)
    rounds = [r for r in sorted(reviews, key=lambda r: r.get("submitted_at") or "")
              if (r.get("body") or "").strip() or per_review.get(r["id"])]
    counts = [len(per_review.get(r["id"], [])) for r in rounds]
    changed = sum(1 for c in top if led_to_change(c, commits))
    bypass = sum(1 for c in top if BYPASS.search(c.get("body") or ""))
    hours = (ts(p["merged_at"]) - ts(p["created_at"])).total_seconds() / 3600
    rows.append((n, p["title"].replace("|", "\\|"), len(rounds),
                 ", ".join(map(str, counts)) or "none", len(top), changed, bypass, hours))

print("Merged PRs in %s, %s to %s (merge date, inclusive)." % (repo, since, until))
print()
print("| PR | Title | Review rounds | Inline comments per round | Comments that led to a change | Bypass candidates | Open to merge (h) |")
print("| --- | --- | --- | --- | --- | --- | --- |")
for n, title, r, per, total, changed, bypass, hours in rows:
    print("| #%d | %s | %d | %s | %d of %d | %d | %.1f |" % (n, title, r, per, changed, total, bypass, hours))
if rows:
    hs = sorted(h for *_, h in rows)
    mid = hs[len(hs) // 2] if len(hs) % 2 else (hs[len(hs) // 2 - 1] + hs[len(hs) // 2]) / 2
    rs = sorted(r[2] for r in rows)
    mr = rs[len(rs) // 2] if len(rs) % 2 else (rs[len(rs) // 2 - 1] + rs[len(rs) // 2]) / 2
    print()
    print("%d PRs. Median review rounds: %g (range %d to %d). Median open to merge: %.1f h (range %.1f to %.1f)."
          % (len(rows), mr, rs[0], rs[-1], mid, hs[0], hs[-1]))
    print("Bypass candidates are comments matching a pattern; read each one before counting it.")
PY
