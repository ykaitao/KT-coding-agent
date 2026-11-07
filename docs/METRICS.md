# Loop metrics

Numbers for every pull request run through the review/implement loop so far, collected from GitHub on 2026-11-07. Open PRs are still in the loop, so their numbers can change. #5 and #10 are issues, not PRs.

## Pull requests

| PR | Title | Review rounds | Inline comments per round | Reproduced security bypass | CI | State |
| --- | --- | --- | --- | --- | --- | --- |
| #1 | Expand README with feature overview | 4 | 8, 2, 2, 0 | no | none | merged |
| #2 | Add reusable PR review skills (Claude, Codex, Copilot) | 3 | 5, 1, 0 | no | none | merged |
| #3 | Ignore .tokensave index directory | 2 | 1, 0 | no | none | merged |
| #4 | Document our way of working and add pr-review-loop skill | 7 | 3, 1, 3, 2, 1, 1, 0 | yes (3) | none | merged |
| #6 | Ship the review-event guard hook with tests; fold loop lessons into skills | 3 | 3, 1, 0 | no | none | merged |
| #7 | Gate the review loop on CI and tests | 2 | 2, 0 | no | pass | merged |
| #8 | Add skills check and per-provider discovery checklist | 2 | 3, 0 | no | pass | merged |
| #9 | Record lessons from running parallel implement/review pairs | 3 | 3, 1, 0 | no | pass | merged |
| #11 | README: goal, what works today, quick start, roadmap | 3 | 4, 1, 0 | no | pass | open |
| #12 | Add cross-tool AGENTS.md | 2 | 1, 0 | no | pass | open |
| #13 | Label review comments by severity; one worktree per implement session | 2 | 3, 1 | no | pass | open |

How each column is defined:

- **Review rounds:** reviews on the PR whose body isn't empty, in order. A round with 0 inline comments is the clean review that ends the loop.
- **Inline comments per round:** top-level inline comments (not replies) attached to each of those reviews. Each one counts as one actionable finding. Findings written only in a review body aren't counted.
- **Reproduced security bypass:** a finding where the reviewer ran the shipped guard hook and showed a command it should block getting through (exit 0). To find these, I searched the comment text for `exit 0`, `exits 0` and `I ran the hook`, then read each match. On #4 there are three: comment 4503667182 (attached `-fevent=APPROVE` flags), 4503676044 (a race on a chained `--input` file) and 4503683885 (the same race with `&`). The two matches on #6 (4503721273 and 4503721293) showed weak test cases that the hook still blocked, so they aren't counted.
- **CI:** conclusions of the check runs on the PR's head commit. `none` means no checks ran; CI was added in #7.

## What the numbers show

- The 8 merged PRs took 26 review rounds (2 to 7 each) and drew 43 inline comments.
- Every merged PR ended on a round with 0 inline comments.
- The first round had the most comments on every PR. On #4, round 3 tied it at 3.
- #4 took the most rounds (7). It is the only PR with a reproduced security bypass: 3, all in the review-event guard.
- Every PR from #7 on has passing CI on its head commit. #1 to #6 had no CI.
- #11, #12 and #13 are open. The latest round on #13 still has 1 inline comment.

## How to record a new PR

After a PR merges, the manager:

1. Runs the collection script below for that PR number, for example `bash collect.sh 14 14`.
2. Reads the PR's inline comments for a reproduced bypass, meaning a reviewer ran the guard and showed exit 0 where it should block. Sets that column to `yes (N)` or `no`.
3. Adds the row to the table and updates any open rows that have since changed. Updates "What the numbers show" only with what the new numbers support.

## Collection script

Save this as `collect.sh` and run `bash collect.sh <first> <last>`. It needs `gh` (signed in) and `jq`. It prints one table row per PR without the bypass column, which needs a person to judge. Each read of a PR's reviews is its own `gh api` call.

```bash
#!/usr/bin/env bash
# Prints one Markdown table row per PR. Usage: bash collect.sh <first> <last>
set -u
repo=ykaitao/KT-coding-agent
for n in $(seq "$1" "$2"); do
  pr="$(gh pr view "$n" --repo "$repo" --json number,title,state,headRefOid 2>/dev/null)" || continue
  title="$(jq -r .title <<<"$pr")"
  state="$(jq -r '.state | ascii_downcase' <<<"$pr")"
  sha="$(jq -r .headRefOid <<<"$pr")"
  # Review rounds: reviews whose body isn't empty, in order.
  ids="$(gh api --paginate "repos/$repo/pulls/$n/reviews" --jq '.[] | select(.body != "") | .id')"
  comments="$(gh api --paginate "repos/$repo/pulls/$n/comments" --jq '.[] | select(.in_reply_to_id == null) | .pull_request_review_id')"
  rounds=0; per=""
  for id in $ids; do
    rounds=$((rounds + 1))
    c="$(grep -cx "$id" <<<"$comments")"
    per="${per:+$per, }$c"
  done
  # CI: conclusions of the check runs on the head commit.
  ci="$(gh api "repos/$repo/commits/$sha/check-runs" --jq '[.check_runs[].conclusion] | if length == 0 then "none" elif all(. == "success") then "pass" else (unique | join("/")) end')"
  echo "| #$n | $title | $rounds | ${per:--} | $ci | $state |"
done
```
