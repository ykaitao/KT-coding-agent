# Measuring the loop

How to show, with numbers from your own PRs, whether the review/implement loop helps. The same script runs before and after, so both periods are measured the same way. [`METRICS.md`](METRICS.md) holds the numbers collected by hand for this repo's first PRs; this page is the repeatable method.

## The script

```bash
scripts/loop-metrics.sh <owner/repo> <since YYYY-MM-DD> <until YYYY-MM-DD>
```

It needs an authenticated `gh` and `python3`. It prints one Markdown table row per PR merged in the window (by merge date, inclusive), then the medians and ranges. Each GitHub read is its own `gh api --paginate <path>` call, so the review-event guard hook doesn't block it. A run over about 20 PRs takes a couple of minutes.

| Column | Meaning |
| --- | --- |
| Review rounds | Reviews with a non-empty body or at least one top-level inline comment, in order. Reviews that only carry thread replies are left out. A review that only holds someone's note (body, no inline comments) still counts, so check for those by hand. |
| Inline comments per round | Top-level inline comments in each of those reviews. Replies aren't counted. |
| Comments that led to a change | Of all top-level inline comments, how many were followed by a commit on the PR that changed the same file within 3 lines of the commented line. |
| Bypass candidates | Comments whose text matches `exit 0`, `exits 0`, `I ran the hook`, or "bypass" near "reproduced" or "exit". These are candidates only: read each one before counting it as a reproduced bypass or bug. |
| Open to merge (h) | Hours from the PR's creation to its merge. |

### Known limits

- **Comments that led to a change** works from line positions. It misses a fix made somewhere else in the file (on PR 24, comment 4503904400 was fixed by adding a check near the top of `install.sh`, far from the commented line), and it can credit a nearby edit that wasn't about the comment. Spot-check a few PRs by hand and report the difference.
- **Bypass candidates** is a text match. On this repo, PR 4's three candidates are real reproduced bypasses, while PR 6's two showed weak tests that the hook still blocked (see [`METRICS.md`](METRICS.md)).
- Findings written only in a review body aren't counted.

## The one-week protocol

1. **Baseline.** Run the script over the 2 to 4 weeks of merged PRs before you adopt the loop.
2. **Adopt.** Install the skills and run 5 to 10 normal PRs through the loop. Don't pick unusually easy or hard ones.
3. **Capture.** At the end of the week, run the script over that week.
4. **Escaped defects.** For both periods, count bug issues or reverts linked to those PRs within 30 days of merge. Label such issues `escaped-defect` so they can be counted with `gh issue list --label escaped-defect`.
5. **Cost.** Record agent session cost or tokens per PR where the provider reports them. Otherwise use open-to-merge time.
6. **Report.** Give the before and after tables, the median and range for each column, and the caveats: a small sample, a different mix of PRs, and the known limits above.

## What to count, and what not to

Count only what can't be inflated by writing more comments:

- **Comments that led to a change**, after the hand spot-check.
- **Reproduced bypasses or bugs**, after reading each candidate.
- **Escaped defects** per period.

Don't report raw inline comment counts on their own as an improvement. They reward noise: a reviewer that posts more trivial comments looks better. Comment counts are context for the rounds, not the result.
