# Loop metrics

Numbers for every pull request run through the review/implement loop so far, collected from GitHub at 2026-11-07 21:48 UTC. Rows are as of that time. Open PRs are still in the loop, so their numbers can change. #5 and #10 are issues, not PRs.

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
| #11 | README: goal, what works today, quick start, roadmap | 3 | 4, 1, 0 | no | pass | merged |
| #12 | Add cross-tool AGENTS.md | 2 | 1, 0 | no | pass | merged |
| #13 | Label review comments by severity; one worktree per implement session | 4 | 3, 1, 1, 0 | no | pass | open |

How each column is defined:

- **Review rounds:** reviews on the PR that have a non-empty body or at least one top-level inline comment, in order. A round with 0 inline comments is the clean review that ends the loop. Replying in a thread creates a review with an empty body whose only comments are replies, so those are excluded. All reviews here come from one account, so a review that only carries an implementer's or the owner's note (non-empty body, no inline comments) would count as a round. Exclude such reviews by hand; none appear in the table.
- **Inline comments per round:** top-level inline comments (not replies) attached to each of those reviews. Each one counts as one actionable finding. Findings written only in a review body aren't counted.
- **Reproduced security bypass:** a finding where the reviewer ran the shipped guard hook and showed a command it should block getting through (exit 0). To find these, I searched the comment text for `exit 0`, `exits 0` and `I ran the hook`, then read each match. On #4 there are three: comment 4503667182 (attached `-fevent=APPROVE` flags), 4503676044 (a race on a chained `--input` file) and 4503683885 (the same race with `&`). The two matches on #6 (4503721273 and 4503721293) showed weak test cases that the hook still blocked, so they aren't counted.
- **CI:** conclusions of the check runs on the PR's head commit. `none` means no checks ran; CI was added in #7.

## What the numbers show

- The 10 merged PRs took 31 review rounds (2 to 7 each) and drew 49 inline comments.
- Every merged PR ended on a round with 0 inline comments.
- The first round had the most comments on every PR. On #4, round 3 tied it at 3.
- #4 took the most rounds (7). It is the only PR with a reproduced security bypass: 3, all in the review-event guard.
- Every PR from #7 on has passing CI on its head commit. #1 to #6 had no CI.
- #13 is open. Its latest round has 0 inline comments.

## Agents

One row per PR and role, for #1 to #30, collected from GitHub at 2026-11-07 22:40 UTC. The missing numbers (#5, #10, #17 to #21 and #25) are issues. #30 was closed without merging.

**Attribution is ambiguous.** Every review, thread reply and commit on GitHub is under the owner's account, `ykaitao`, and every commit is authored "Kaitao Yang" with a `Co-Authored-By: Claude` trailer. GitHub can't tell the reviewer and implementer sessions apart, or show which session did what. So the role here comes from the kind of action: reviews mean reviewer, while commits and thread replies mean implementer. No session is named.

| PR | Role | Attribution | Rounds | Must-fix found | Must-fix received | Reproduced bypasses | Replies missing | State |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| #1 | reviewer | ykaitao | 4 | unlabelled | - | 0 | - | merged |
| #1 | implementer | Kaitao Yang+Claude, branch `docs/readme-update` | 4 | - | unlabelled | - | 0 | merged |
| #2 | reviewer | ykaitao | 3 | unlabelled | - | 0 | - | merged |
| #2 | implementer | Kaitao Yang+Claude, branch `feat/pr-review-skills` | 3 | - | unlabelled | - | 0 | merged |
| #3 | reviewer | ykaitao | 2 | unlabelled | - | 0 | - | merged |
| #3 | implementer | Kaitao Yang+Claude, branch `chore/ignore-tokensave` | 2 | - | unlabelled | - | 0 | merged |
| #4 | reviewer | ykaitao | 7 | unlabelled | - | 3 | - | merged |
| #4 | implementer | Kaitao Yang+Claude, branch `docs/way-of-working` | 7 | - | unlabelled | - | 0 | merged |
| #6 | reviewer | ykaitao | 3 | unlabelled | - | 0 | - | merged |
| #6 | implementer | Kaitao Yang+Claude, branch `feat/skill-lessons-and-hook` | 3 | - | unlabelled | - | 0 | merged |
| #7 | reviewer | ykaitao | 2 | unlabelled | - | 0 | - | merged |
| #7 | implementer | Kaitao Yang+Claude, branch `ci/gate-loop-on-checks` | 2 | - | unlabelled | - | 0 | merged |
| #8 | reviewer | ykaitao | 2 | unlabelled | - | 0 | - | merged |
| #8 | implementer | Kaitao Yang+Claude, branch `feat/skills-check` | 2 | - | unlabelled | - | 0 | merged |
| #9 | reviewer | ykaitao | 3 | unlabelled | - | 0 | - | merged |
| #9 | implementer | Kaitao Yang+Claude, branch `docs/parallel-pair-lessons` | 3 | - | unlabelled | - | 0 | merged |
| #11 | reviewer | ykaitao | 3 | unlabelled | - | 0 | - | merged |
| #11 | implementer | Kaitao Yang+Claude, branch `docs/readme-quickstart` | 3 | - | unlabelled | - | 0 | merged |
| #12 | reviewer | ykaitao | 2 | unlabelled | - | 0 | - | merged |
| #12 | implementer | Kaitao Yang+Claude, branch `docs/agents-md` | 2 | - | unlabelled | - | 0 | merged |
| #13 | reviewer | ykaitao | 4 | 5 | - | 0 | - | merged |
| #13 | implementer | Kaitao Yang+Claude, branch `docs/loop-severity-and-worktrees` | 4 | - | 5 | - | 0 | merged |
| #14 | reviewer | ykaitao | 1 | 0 | - | 0 | - | merged |
| #14 | implementer | Kaitao Yang+Claude, branch `feat/claude-plugin` | 1 | - | 0 | - | 0 | merged |
| #15 | reviewer | ykaitao | 1 | 0 | - | 0 | - | merged |
| #15 | implementer | Kaitao Yang+Claude, branch `docs/loop-metrics` | 1 | - | 0 | - | 0 | merged |
| #16 | reviewer | ykaitao | 2 | 1 | - | 0 | - | merged |
| #16 | implementer | Kaitao Yang+Claude, branch `docs/manager-playbook` | 2 | - | 1 | - | 0 | merged |
| #22 | reviewer | ykaitao | 2 | 1 | - | 0 | - | merged |
| #22 | implementer | Kaitao Yang+Claude, branch `docs/skill-lessons-3` | 2 | - | 1 | - | 0 | merged |
| #23 | reviewer | ykaitao | 3 | 1 | - | 0 | - | merged |
| #23 | implementer | Kaitao Yang+Claude, branch `feat/code-health-scan` | 3 | - | 1 | - | 0 | merged |
| #24 | reviewer | ykaitao | 2 | 4 | - | 0 | - | merged |
| #24 | implementer | Kaitao Yang+Claude, branch `feat/install-script` | 2 | - | 4 | - | 0 | merged |
| #26 | reviewer | ykaitao | 3 | 5 | - | 5 | - | open |
| #26 | implementer | Kaitao Yang+Claude, branch `fix/guard-fail-closed` | 3 | - | 5 | - | 0 | open |
| #27 | reviewer | ykaitao | 1 | 0 | - | 0 | - | merged |
| #27 | implementer | Kaitao Yang+Claude, branch `feat/skills-markdown-and-cleanup` | 1 | - | 0 | - | 0 | merged |
| #28 | reviewer | ykaitao | 2 | 1 | - | 0 | - | open |
| #28 | implementer | Kaitao Yang+Claude, branch `feat/skills-leak-check` | 2 | - | 1 | - | 0 | open |
| #29 | reviewer | ykaitao | 2 | 0 | - | 0 | - | open |
| #29 | implementer | Kaitao Yang+Claude, branch `feat/system-design-skill` | 2 | - | 0 | - | 0 | open |
| #30 | reviewer | none | 0 | 0 | - | 0 | - | closed |
| #30 | implementer | Kaitao Yang+Claude, branch `claude/install-script-b7c047` | 0 | - | 0 | - | 0 | closed |

How each column is defined:

- **Rounds:** as in the table above, but taken now, so the open rows from the first table may differ.
- **Must-fix found / received:** top-level inline comments whose text starts with `must-fix` (bold or not). Severity labels started with #13. Before that, comments carry no label and show as `unlabelled`. The reviewer finds them and the implementer receives them, so the two numbers are the same.
- **Reproduced bypasses:** findings where the reviewer ran the guard hook and showed a command getting through that should be blocked, judged by reading the comments. #4 has the three listed above. #26 has five comments labelled `must-fix (bypass)`, each showing a command the hook allowed: 4503924434, 4503924439, 4503924442, 4503954735 and 4503954738.
- **Replies missing:** top-level inline comments with no reply in their thread.

What these rows show:

- Every inline comment on every PR has a reply.
- Since labels began, reviewers found must-fix comments on #13 (5), #16 (1), #22 (1), #23 (1), #24 (4), #26 (5) and #28 (1).
- Reproduced bypasses appear only on the two PRs that changed the guard hook, #4 and #26.

## How to record a new PR

After a PR merges, the manager updates this file and [`LESSONS.md`](LESSONS.md); see "How to use" there. Here the manager:

1. Runs the collection script below for that PR number, for example `bash collect.sh 14 14`.
2. Reads the PR's inline comments for a reproduced bypass, meaning a reviewer ran the guard and showed exit 0 where it should block. Sets that column to `yes (N)` or `no`.
3. Adds the row to the table and updates any open rows that have since changed. Updates "What the numbers show" only with what the new numbers support.
4. Runs the agents script below for that PR, fills in the reviewer's bypass column (`?`) by hand, and adds the two rows to the Agents table.

## Collection script

Save this as `collect.sh` and run `bash collect.sh <first> <last>`. It needs `gh` (signed in) and `jq`. To use it on another repository, set `REPO`, for example `REPO=owner/name bash collect.sh 1 20`. It prints one table row per PR without the bypass column, which needs a person to judge. Each read of a PR's reviews is its own `gh api` call.

```bash
#!/usr/bin/env bash
# Prints one Markdown table row per PR. Usage: bash collect.sh <first> <last>
set -u
repo="${REPO:-ykaitao/KT-coding-agent}"
for n in $(seq "$1" "$2"); do
  pr="$(gh pr view "$n" --repo "$repo" --json number,title,state,headRefOid 2>/dev/null)" || continue
  title="$(jq -r .title <<<"$pr")"
  state="$(jq -r '.state | ascii_downcase' <<<"$pr")"
  sha="$(jq -r .headRefOid <<<"$pr")"
  # Review rounds: reviews with a non-empty body or at least one top-level inline comment, in order.
  reviews="$(gh api --paginate "repos/$repo/pulls/$n/reviews" --jq '.[] | "\(.id) \(.body != "")"')"
  comments="$(gh api --paginate "repos/$repo/pulls/$n/comments" --jq '.[] | select(.in_reply_to_id == null) | .pull_request_review_id')"
  rounds=0; per=""
  while read -r id has_body; do
    [ -n "$id" ] || continue
    c="$(grep -cx "$id" <<<"$comments")"
    [ "$has_body" = true ] || [ "$c" -gt 0 ] || continue
    rounds=$((rounds + 1))
    per="${per:+$per, }$c"
  done <<<"$reviews"
  # CI: conclusions of the check runs on the head commit.
  ci="$(gh api "repos/$repo/commits/$sha/check-runs" --jq '[.check_runs[].conclusion] | if length == 0 then "none" elif all(. == "success") then "pass" else (unique | join("/")) end')"
  echo "| #$n | $title | $rounds | ${per:--} | $ci | $state |"
done
```

## Agents script

Save this as `agents.sh` and run `bash agents.sh <first> <last>`. It needs `gh` (signed in) and `jq`, and it honours `REPO` the same way. It prints two rows per PR, and leaves the bypass column as `?` for a person to fill in.

```bash
#!/usr/bin/env bash
# Prints two Markdown rows per PR (reviewer, implementer). Usage: bash agents.sh <first> <last>
set -u
repo="${REPO:-ykaitao/KT-coding-agent}"
for n in $(seq "$1" "$2"); do
  pr="$(gh pr view "$n" --repo "$repo" --json number,headRefName,state 2>/dev/null)" || continue
  branch="$(jq -r .headRefName <<<"$pr")"
  state="$(jq -r '.state | ascii_downcase' <<<"$pr")"
  reviews="$(gh api --paginate "repos/$repo/pulls/$n/reviews" --jq '.[] | "\(.id) \(.body != "") \(.user.login)"')"
  comments="$(gh api --paginate "repos/$repo/pulls/$n/comments" --jq '.[] | [.id, (.in_reply_to_id // 0), (.pull_request_review_id // 0), ((.body | test("^\\s*(\\*\\*)?must-fix"; "i")) | tostring), ((.body | test("^\\s*(\\*\\*)?(must-fix|nit|should-fix)"; "i")) | tostring)] | @tsv')"
  top="$(awk -F'\t' '$2 == 0' <<<"$comments")"
  rounds=0; reviewers=""
  while read -r id has_body login; do
    [ -n "$id" ] || continue
    c="$(awk -F'\t' -v r="$id" '$3 == r' <<<"$top" | grep -c .)"
    [ "$has_body" = true ] || [ "$c" -gt 0 ] || continue
    rounds=$((rounds + 1))
    case " $reviewers " in *" $login "*) ;; *) reviewers="${reviewers:+$reviewers }$login" ;; esac
  done <<<"$reviews"
  total="$(grep -c . <<<"$top")"
  labelled="$(awk -F'\t' '$5 == "true"' <<<"$top" | grep -c .)"
  mustfix="$(awk -F'\t' '$4 == "true"' <<<"$top" | grep -c .)"
  [ "$total" -gt 0 ] && [ "$labelled" -eq 0 ] && mustfix="unlabelled"
  [ "$total" -eq 0 ] && mustfix=0
  replied="$(awk -F'\t' '$2 != 0 {print $2}' <<<"$comments" | sort -u)"
  missing=0
  for id in $(awk -F'\t' '{print $1}' <<<"$top"); do
    grep -qx "$id" <<<"$replied" || missing=$((missing + 1))
  done
  authors="$(gh api --paginate "repos/$repo/pulls/$n/commits" --jq '.[] | select(.parents | length == 1) | "\(.author.login // .commit.author.name)\(if (.commit.message | test("Co-Authored-By: Claude"; "i")) then "+Claude" else "" end)"' | sort -u | paste -sd ' ' -)"
  # The bypass column (?) needs a person to judge; see the column definitions.
  echo "| #$n | reviewer | ${reviewers:-none} | $rounds | $mustfix | - | ? | - | $state |"
  echo "| #$n | implementer | $authors, branch \`$branch\` | $rounds | - | $mustfix | - | $missing | $state |"
done
```
