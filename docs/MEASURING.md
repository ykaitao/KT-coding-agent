# Measuring the loop

How to show, with numbers from your own PRs, whether the review/implement loop helps. The same script runs before and after, so both periods are measured the same way. [`METRICS.md`](METRICS.md) holds the numbers collected by hand for this repo's first PRs; this page is the repeatable method.

## The script

```bash
scripts/loop-metrics.sh <owner/repo> <since YYYY-MM-DD> <until YYYY-MM-DD>
```

It needs an authenticated `gh` and `python3`. It prints one Markdown table row per PR merged in the window (by merge date, inclusive), then the medians and ranges. Each GitHub read is its own `gh api --paginate <path>` call, so the review-event guard hook doesn't block it. A run over about 20 PRs takes a couple of minutes. To spot-check a few PRs, set `LOOP_METRICS_PRS="1 4 24"` to limit the table to those numbers.

| Column | Meaning |
| --- | --- |
| Review rounds | One round per reviewed head commit. Reviews on the same commit, such as a round split into two posts or a blocked draft the manager posted next to the reviewer's, count once. Only reviews with a non-empty body or at least one top-level inline comment count; reviews that only carry thread replies are left out. A review that only holds someone's note (body, no inline comments) on a new commit still counts, so check for those by hand. |
| Inline comments per round | Top-level inline comments in each round, summed over its reviews. Replies aren't counted. |
| Comments that led to a change | Of all top-level inline comments, how many led to a commit, shown as "by reply" and "by line". **By reply** (first): a reply in the thread names a commit on the PR that touches the comment's file, as `pr-address-review` asks implementers to do. A reply that defers or skips the comment without naming a commit counts as no change. **By line** (fallback, when no reply decides it): a later commit on the PR changes the commented lines (from `original_start_line` to `original_line`) of that file, within 3 lines, also after a rename. Merge commits are skipped, because they diff against the base branch. |
| Bypass candidates | Comments whose text matches `exit 0`, `exits 0`, `I ran the hook`, or "bypass" near "reproduced" or "exit". These are candidates only: read each one before counting it as a reproduced bypass or bug. |
| Open to merge (h) | Hours from the PR's creation to its merge. |

### Known limits

- **Comments that led to a change** trusts the implementer's reply: a commit that touches the file but doesn't fix the comment still counts. The line fallback misses a fix made elsewhere in the file and can credit a nearby edit that wasn't about the comment. Before the reply signal, PR 24's comment 4503904400 (fixed near the top of `install.sh`) was missed and PR 23's comment 4503912655 (deferred to another issue) was credited; both are now right. Spot-check a few PRs by hand and report the difference.
- **Force-pushes, rebases and squashes** rewrite the commit list: the old commits disappear, and the new ones get new dates and SHAs. Replies then cite SHAs that are no longer on the PR, so the line fallback runs, and a squash after review can credit every comment in its range. Treat such PRs' numbers as rough.
- **Bypass candidates** is a text match. On this repo, PR 4's three candidates are real reproduced bypasses, while PR 6's two showed weak tests that the hook still blocked (see [`METRICS.md`](METRICS.md)).
- Findings written only in a review body aren't counted.

## The one-week protocol

1. **Baseline.** Run the script over the 2 to 4 weeks of merged PRs before you adopt the loop.
2. **Adopt.** Install the skills and run 5 to 10 normal PRs through the loop. Don't pick unusually easy or hard ones.
3. **Capture.** At the end of the week, run the script over that week.
4. **Escaped defects.** For both periods, count bug issues or reverts linked to those PRs within 30 days of merge. Label such issues `escaped-defect` so they can be counted with `gh issue list --label escaped-defect`. The label only starts being used when you adopt the loop, so the baseline would look cleaner than it was. Before comparing, go back over the baseline period and label its linked bug issues and reverts the same way, with the same 30-day window. Do that before you look at the after numbers.
5. **Cost.** Record agent session cost or tokens per PR where the provider reports them. Otherwise use open-to-merge time.
6. **Report.** Give the before and after tables, the median and range for each column, and the caveats: a small sample, a different mix of PRs, and the known limits above.

## What to count, and what not to

Count only what can't be inflated by writing more comments:

- **Comments that led to a change**, after the hand spot-check.
- **Reproduced bypasses or bugs**, after reading each candidate.
- **Escaped defects** per period.

Don't report raw inline comment counts on their own as an improvement. They reward noise: a reviewer that posts more trivial comments looks better. Comment counts are context for the rounds, not the result.
