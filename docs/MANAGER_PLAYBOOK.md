# Manager playbook

Practical lessons for whoever acts as the manager in the review/implement loop, whether a person or an agent. The process itself is in [`WAY_OF_WORKING.md`](WAY_OF_WORKING.md) and the loop steps are in [`pr-review-loop`](../skills/pr-review-loop/SKILL.md). This page doesn't repeat them; it covers what went wrong while running them and what the manager does about it. PR numbers are cited as evidence where GitHub shows it; other lessons are marked "(manager's account)".

## 1. Briefs

A session knows only what its brief says. A good brief:

- **Lists the concerns.** For a reviewer, name each concern you want checked (for example "does the guard still block `-fevent=APPROVE`?"), not just "review PR N". For an implementer, list each comment ID with its path, line and gist.
- **Names the files to stay out of.** When two pairs run in parallel, say which files belong to the other pair, for example "don't touch `.github/workflows/` or `skills/pr-review-loop/SKILL.md`; another session is editing them".
- **Says what the report must contain.** For example: PR URL, head SHA, test output, a table of each failure path tried, and anything not verified. A required "not verified" line makes gaps visible instead of hidden.
- **Says where to start.** "Fetch, then branch from `origin/master`" and "work in your own worktree", every time.
- **Says what to do when blocked.** For example: "if a post is blocked, save the text to a file and report its path; don't work around it".

The reviewer's side is in [`pr-inline-review`](../skills/pr-inline-review/SKILL.md), and the implementer's side is in [`pr-address-review`](../skills/pr-address-review/SKILL.md).

## 2. Verify every report

A report is a claim. Before you tell the owner something is done, check it on GitHub:

- **Head SHA:** `gh pr view N --json headRefOid` matches the SHA in the report.
- **Files:** `gh pr diff N --name-only` lists only the files in scope.
- **Comment lines:** each inline comment's `line` holds the text it's about.
- **Replies:** each thread has a reply (`in_reply_to_id` set).
- **CI:** `gh pr checks N` passes on the current head.

For security claims, rerun the tests and probes yourself; don't take "blocked" or "allowed" on trust.

Evidence from this repo:

- **PR 1** (manager's account; not visible in the PR's GitHub history): a reviewer reported deleting comments it never deleted. That is why "trust only what's verified" is a principle in [`WAY_OF_WORKING.md`](WAY_OF_WORKING.md).
- **PR 9:** a claim about the guard hook in the PR's text was wrong; that it was the manager's own claim is the manager's account. The draft said the hook blocks any command that combines a reviews request with other commands. The reviewer fed the hook real inputs and showed that chains whose parts use only read flags get through. The manager is not exempt from verification.

## 3. Parallel pairs

Running several PRs at once is covered in "Parallel pairs" in [`pr-review-loop`](../skills/pr-review-loop/SKILL.md). In practice:

- **Split work by files.** Pick tasks that touch different files, and say so in each brief. PR 7 (CI and a loop-skill line) ran next to PR 8 (the skills check and `skills/README.md`) without conflicts.
- **One worktree per implementer.** Each implement session gets its own worktree and branch. Review sessions only read through `gh`, so they share the main checkout.
- **Copy local settings into new worktrees.** `.claude/settings.local.json` is untracked, so a new worktree starts without its allow rules and without the review-event guard (PR 9).
- **Capacity is limited.** The real limits are your own attention, since every report needs verifying, and disk space: a session failed to start with 4.3 GB free (manager's account). Check `df -h` before starting another pair.
- **Clean up after each merge.** Remove the worktree, delete the local branch, and prune. The commands are under "Finish" in `pr-review-loop`.

## 4. Standing preferences from the owner

These began as the manager's private memory: notes one agent kept across its own sessions. Nobody else could see or follow them. Writing them here, as general rules, makes them shareable with anyone who takes the manager role.

- **The owner talks only to the manager.** The manager steers the other sessions and never sends the owner to them.
- **Delegated work runs in visible sessions.** Reviews and implementations run in sessions the owner can open and watch, not in hidden subagents.
- **Keep pairs busy with non-overlapping work.** When a pair finishes, give it the next task that doesn't touch files another pair is working on.
- **Rename sessions to "handle: task".** For example "review1: PR 8 skills check", so the session list shows who is doing what.
- **Clean up after each merge.** See "Clean up after each merge" in section 3.
- **Turn every round's lessons into skill fixes.** After each round, judge how the agents did. Fix the skill or the brief through a PR, as PR 6 and PR 9 did.

## 5. When blocked

These match "Approvals belong to the owner, given to the manager" and "Permissions" in [`WAY_OF_WORKING.md`](WAY_OF_WORKING.md).

The manager **may**:

- Post another session's saved review draft when a permission check blocked that session's post. Use only permissions the owner granted the manager, and first check three things: its `event` is `COMMENT`, its `commit_id` is the PR head, and every comment's `line` holds the text it's about.
- Ask the blocked session to save its text to a file and report the path.

The manager **may not**:

- Work around its own blocked action. Instead, tell the owner which permission rule is missing.
- Approve, request changes, merge, push to the default branch, or delete anything on GitHub without the owner's word.

## 6. Common slips and their fixes

| Slip | Fix |
| --- | --- |
| An agent forgets to fetch before branching, so its branch starts from a stale `master` (manager's account). | Put "run `git fetch`, then branch from `origin/master`" in every brief, and check the PR's base commit when it opens. |
| A reviewer drops a concern from the brief, and the review comes back clean on everything else (manager's account). | Compare the review against the brief's list of concerns before you accept it. If one is missing, send it back. |
| A test passes for the wrong reason. | Prove the test with a mutation: disable the check it targets and confirm the test fails. On PR 6, two hook test cases still passed with the operator check disabled; the replacements fail without it. |
| A PR that predates CI never ran the new checks. | Update the branch from `master` (`gh pr update-branch`, GitHub's "Update branch", or merge `master` in) before the last review round, so CI runs on its head. PR 8 was updated this way after PR 7 added CI. Re-read the head SHA afterwards because it changes, have the reviewer look at the new head, and tell implement to pull before its next push. See "Finish" in `pr-review-loop`. |
| A shell command that only mentions a reviews endpoint is blocked by the guard hook. | Use a file-editing tool for docs edits, and run each `gh api` read of reviews as its own command (see the Rules in `pr-review-loop`). |
