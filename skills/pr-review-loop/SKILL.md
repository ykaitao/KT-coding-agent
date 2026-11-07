---
name: pr-review-loop
description: Run a pull request through alternating review and implement rounds until a review finds no actionable comments, then merge on the owner's word and clean up. Use when asked to "run the review/implement loop" on a PR.
---

# PR review loop (manager)

You orchestrate. Two visible sessions do the work: **review** follows `pr-inline-review` and **implement** follows `pr-address-review`. Reuse existing sessions with those names if there are any; otherwise start new ones the owner can watch.

## Loop
1. Ask review to review PR `<n>` at its current head. Brief it with the repo, the PR, the head SHA, what changed since the last round, and "report the review URL, the number of actionable comments, and the line plus gist for each".
2. When review reports back, **check it**: fetch the review and its comments (`gh api --paginate .../pulls/<n>/comments`), confirm the head SHA and that each comment's `line` holds the text it's about.
   - If there are 0 actionable comments, the loop is done; go to "Finish".
   - If posting was blocked by permissions, tell the owner to approve it in the review session. Don't post it yourself or through another agent unless the owner tells you to directly.
3. Send the comments (IDs, paths, lines, gists) to implement with the file scope and the rules: only touch these files, don't stage unrelated edits, and don't switch a shared checkout's branch (use a `git worktree` if needed).
4. When implement reports back, **check it**: confirm the new PR head, the changed files, the edits and one reply per comment. Then go back to step 1.

After each round, judge each agent's work. If something went wrong, improve the skill or the brief before the next round. If the work went well and the task will recur, propose a new skill.

## Finish
- Report to the owner: rounds run, final review URL, and anything left unverified. Merge only on their word.
- After the merge, run `git fetch --prune`, remove any worktrees for the branch, `git branch -d <branch>`, and fast-forward the default branch.

## Rules
- Never approve, resolve threads, or merge on your own initiative.
- Never report something to the owner that you haven't checked on GitHub.
