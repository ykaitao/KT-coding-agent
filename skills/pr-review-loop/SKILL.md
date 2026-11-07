---
name: pr-review-loop
description: Run a pull request through alternating review and implement rounds until a review finds no actionable comments, then merge on the owner's word and clean up. Use when asked to "run the review/implement loop" on a PR.
---

# PR review loop (manager)

You orchestrate and are the owner's only point of contact: relay their decisions to the sessions, and never send them to another session to answer. Two visible sessions do the work: **review** follows `pr-inline-review` and **implement** follows `pr-address-review`. Reuse existing sessions with those names if there are any; otherwise start new ones the owner can watch.

## Parallel pairs

To run several PRs at once, give each one its own pair (for example `implement1`/`review1`), and only run as many pairs as you can verify properly; two worked well.

- Pick work whose PRs touch different files, and tell each implement session which files to stay out of.
- Each implement session gets its own worktree and branch. Review sessions only read through `gh`, so they can share the main checkout and its settings.
- Untracked files such as `.claude/settings.local.json` aren't copied into new worktrees, so a worktree session runs without that file's allow rules and without the review-event guard hook: nothing stops it from posting an `APPROVE` or `REQUEST_CHANGES` review, and its thread replies may need approval. Copy or symlink the file into the worktree before the session starts (newer Claude Code versions can also copy gitignored files listed in a `.worktreeinclude` file at the repo root).

## Loop
1. Ask review to review PR `<n>` at its current head. Brief it with the repo, the PR, the head SHA, what changed since the last round, and "report the review URL, the number of actionable comments, and the line plus gist for each".
2. When review reports back, **check it**: fetch the review and its comments (`gh api --paginate .../pulls/<n>/comments`), confirm the head SHA and that each comment's `line` holds the text it's about.
   - If there are 0 actionable comments, the loop is done; go to "Finish".
   - If review's post was blocked, read its saved draft and check that its `event` is `COMMENT`, its `commit_id` is the PR head, and every comment's `line` holds the text it's about. Then post it if your own permissions allow it. If you're blocked too, don't work around it: tell the owner which permission rule is missing (see "Permissions" in `docs/WAY_OF_WORKING.md`). The owner talks only to you, so never ask them to answer inside another session.
   - Sessions started before a settings change may not pick it up. If they're still blocked after a rule is added, start fresh sessions.
3. Send the comments (IDs, paths, lines, gists) to implement with the file scope and the rules: only touch these files, don't stage unrelated edits, and don't switch a shared checkout's branch (use a `git worktree` if needed).
4. When implement reports back, **check it**: confirm the new PR head, the changed files, the edits and one reply per comment. For security fixes, rerun the tests yourself; don't rely on the report alone. Then go back to step 1.

Keep the loop bounded: only must-fix issues keep it going. After 4 rounds, report to the owner what's left and ask whether to continue. Security code may need more rounds; say so when it does.

After each round, judge each agent's work. If something went wrong, improve the skill or the brief before the next round. If the work went well and the task will recur, propose a new skill. If the reviewer dropped a concern you raised, or the implementer skipped tests, fix the skill, not just the next brief.

## Finish
- A PR opened before a CI workflow existed has no checks yet. After that workflow merges, run `gh pr update-branch <n> --repo <owner/repo>`, preferably before the last review round. It adds a merge commit, so the head moves: review the new head (at least the merged-in diff), confirm checks at that head, and tell implement to pull before its next push.
- A PR isn't ready to merge until its checks pass. Confirm it with `gh pr checks <n> --repo <owner/repo>` at the final head before asking the owner to merge. If a check fails, send the failure to implement as another round. If checks are pending, wait (`gh pr checks <n> --repo <owner/repo> --watch`) before asking.
- Report to the owner: rounds run, final review URL, check results, and anything left unverified. Merge only on their word.
- After the merge, run `git fetch --prune`, remove any worktrees for the branch, fast-forward the default branch, then `git branch -d <branch>` (`-D` after a squash or rebase merge, once GitHub shows the PR as merged). Also delete the local branches that worktree sessions created (for example `claude/<name>`) once their worktrees are removed, and check `git branch -vv` for any marked `[gone]`.

## Rules
- Run each `gh api` read of a PR's reviews as its own command. The guard hook treats a command that mentions a reviews endpoint as a write if any part uses a flag outside `gh api`'s read flags (for example `head -n` or `git log --oneline`), and then blocks it if it is chained (`;`, `&&`, `|` and so on). Chains whose parts use only read flags get through, so don't read a pass as the hook being broken. It can also block a shell command whose text merely mentions a reviews endpoint, such as a heredoc that edits these docs; use a file-editing tool for those edits.
- Never approve, resolve threads, or merge on your own initiative.
- Never report something to the owner that you haven't checked on GitHub.
