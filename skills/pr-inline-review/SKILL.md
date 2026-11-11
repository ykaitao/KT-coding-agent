---
name: pr-inline-review
description: Review a GitHub pull request and post accurate, line-verified inline comments as a single COMMENT review. Use when asked to review a PR, or to re-review it after fixes in an implement/review loop.
---

# PR inline review

## Steps
1. Read the diff (`gh pr diff <n> --repo <owner/repo>`) and the existing threads (`gh api --paginate repos/<owner/repo>/pulls/<n>/comments`). Get the head SHA from `gh pr view <n> --repo <owner/repo> --json headRefOid -q .headRefOid`.
2. On a re-review, first check that each earlier comment was really addressed. Then look only for NEW actionable issues. Don't repeat resolved points, and leave out praise-only comments and pure style nitpicks.
3. Address every concern the brief raises: either comment on it or say in the review body why it doesn't hold. Never drop one silently.
4. Look for correctness, overclaiming (statements the code doesn't support), unclear wording, rendering or syntax issues, typos, and inconsistencies.
   - For request-size or input-length limits, verify the bound against the exact serialized or encoded representation sent over the wire, not a pre-serialization estimate; include inputs whose escaping or encoding expands.
   - For progress indicators, verify that 100% means all work is complete, including per-item retries and fallbacks. Exercise retry/fallback cases and a single isolated item so progress cannot reach its terminal state early or remain absent.
   - For security-relevant code (permission checks, hooks, validators), try to break it: build inputs that should be rejected and run them. Report only bypasses you reproduced, with the exact input and result. On a re-review, rerun every bypass you found in earlier rounds against the new version too, since a fix for one case can reopen another.
   - For AST/source scanners, verify binding identity and runtime effects: test storage-object aliases (including aliases through `globalThis.window`), shadowed browser globals and helpers, aliased/destructured references, reassignment, computed writes, and `Object.defineProperty`; mutation-test each guard (PR #1901).
   - When citing evidence, prefer what GitHub still shows (a commit, a comment, a check run) and link it. If a claim rests only on someone's account, such as a session report or a deleted comment, say so ("per the implement session's report") rather than stating it as fact.
   - Label every inline comment by starting its body with `**must-fix:**` (wrong, broken, insecure, misleading, or contradicting other docs) or `**nit:**` (a small improvement the PR is fine without). Security, correctness, data-loss and permission issues (including anything touching hooks or validators, and any reproduced bypass) are always must-fix, never nit; when unsure, use must-fix. Only must-fix comments keep the review loop going.
5. Post ONE review with event `COMMENT` by writing the review JSON to a file first, then posting it as a standalone command with a literal path: `gh api repos/<owner/repo>/pulls/<n>/reviews -X POST --input /abs/path/review.json` (no shell variables, `~`, or `&&`; a guard hook may block anything else), with `commit_id` set to the head SHA and inline `comments` (`path`, `line`, `side: RIGHT`). Use ```` ```suggestion ```` blocks for concrete rewrites.
   - Map every `line` to the NEW-file line number in the diff hunk, and check that the line holds the text you're commenting on (never a blank line).
   - If nothing is actionable, post one `COMMENT` review whose body says "No actionable comments." If there are only nits, say "No must-fix comments" in the body and post the nits inline.
6. Verify: re-fetch the comments and confirm each one is on the intended line. Run each read of the PR's reviews as its own command; the guard hook can block chained commands that touch reviews (see Rules in `pr-review-loop`). If you delete or repost anything, re-fetch again. Never report an action you haven't verified.
   - Don't verify with `GET .../pulls/<n>/reviews/<review_id>/comments`: it returns `line: null` even for correctly placed comments. Use `GET .../pulls/comments/<id>` (or the paginated PR comments list) and compare `line` plus the last line of `diff_hunk`.
   - To check that a line holds the intended text, read the file at the head SHA (`gh api "repos/<owner/repo>/contents/<path>?ref=<sha>" --jq .content | base64 -d | sed -n '<line>p'`) rather than counting lines in `gh pr diff` output.
   - If posting is blocked, don't work around it yourself. Keep the file and report its absolute path. The manager checks that its `event` is `COMMENT`, its `commit_id` is the PR head, and every comment's `line` holds the text it's about, and posts it only if the owner granted the manager that permission; otherwise the manager tells the owner which rule is missing.
   - A 422 "Line could not be resolved" error means a line falls outside the diff hunks, and nothing was posted.

## Rules
- Do not edit files, commit, push, approve, request changes, or merge.
- No bare `@mentions`.

## Report
The review URL, the number of must-fix and nit comments (0 if none), and for each comment its line, label and a one-line gist.
