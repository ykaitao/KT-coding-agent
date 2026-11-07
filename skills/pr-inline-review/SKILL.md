---
name: pr-inline-review
description: Review a GitHub pull request and post accurate, line-verified inline comments as a single COMMENT review. Use when asked to review a PR, or to re-review it after fixes in an implement/review loop.
---

# PR inline review

## Steps
1. Read the diff (`gh pr diff <n> --repo <owner/repo>`) and the existing threads (`gh api --paginate repos/<owner/repo>/pulls/<n>/comments`). Get the head SHA from `gh pr view <n> --repo <owner/repo> --json headRefOid -q .headRefOid`.
2. On a re-review, first check that each earlier comment was really addressed. Then look only for NEW actionable issues. Don't repeat resolved points, and leave out praise-only comments and pure style nitpicks.
3. Look for correctness, overclaiming (statements the code doesn't support), unclear wording, rendering or syntax issues, typos, and inconsistencies.
4. Post ONE review with event `COMMENT` via `gh api repos/<owner/repo>/pulls/<n>/reviews -X POST --input <json>`, with `commit_id` set to the head SHA and inline `comments` (`path`, `line`, `side: RIGHT`). Use ```` ```suggestion ```` blocks for concrete rewrites.
   - Map every `line` to the NEW-file line number in the diff hunk, and check that the line holds the text you're commenting on (never a blank line).
   - If nothing is actionable, post one `COMMENT` review whose body says "No actionable comments."
5. Verify: re-fetch the comments and confirm each one is on the intended line. If you delete or repost anything, re-fetch again. Never report an action you haven't verified.
   - Don't verify with `GET .../pulls/<n>/reviews/<review_id>/comments`: it returns `line: null` even for correctly placed comments. Use `GET .../pulls/comments/<id>` (or the paginated PR comments list) and compare `line` plus the last line of `diff_hunk`.
   - To check that a line holds the intended text, read the file at the head SHA (`gh api "repos/<owner/repo>/contents/<path>?ref=<sha>" --jq .content | base64 -d | sed -n '<line>p'`) rather than counting lines in `gh pr diff` output.
   - A 422 "Line could not be resolved" error means a line falls outside the diff hunks, and nothing was posted.

## Rules
- Do not edit files, commit, push, approve, request changes, or merge.
- No bare `@mentions`.

## Report
The review URL, the number of actionable comments (0 if none), and for each comment its line plus a one-line gist.
