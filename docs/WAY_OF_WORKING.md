# Way of working

How we ship changes with AI coding agents. Every change goes through a pull request, every PR goes through a review loop, and a human makes every decision that can't easily be undone.

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| **Owner** | Human | Talks only to the manager: asks for work and decides on merges. |
| **Manager** | The main agent session | Splits work into PRs, starts and briefs the other sessions, checks every report against GitHub, runs the loop, merges on the owner's word, cleans up. |
| **Implement** | A visible agent session | Addresses review comments with the [`pr-address-review`](../skills/pr-address-review/SKILL.md) skill. |
| **Review** | A visible agent session | Reviews PRs with the [`pr-inline-review`](../skills/pr-inline-review/SKILL.md) skill. |

Delegated work runs in **visible sessions** the owner can open and watch, not in hidden background agents.

**The owner talks only to the manager.** The manager has full control of the other sessions: it starts them, briefs them, and passes on the owner's decisions. The owner never has to answer a question inside another session, so each session's permissions must allow its routine GitHub writes (see "Permissions" below).

## The loop

The full procedure is the [`pr-review-loop`](../skills/pr-review-loop/SKILL.md) skill. In short:

1. **One concern per PR.** Branch from an up-to-date `master` and commit only the files that belong to this change. Never sweep unrelated local edits into the commit.
2. **Review:** the review session posts one `COMMENT` review with line-checked inline comments, or "No actionable comments." It never approves, merges or edits.
3. **Check the review:** the manager confirms on GitHub that the comments exist and sit on the stated lines.
4. **Implement:** the implement session makes minimal edits, pushes, and replies in every thread.
5. **Check the fixes:** the manager confirms on GitHub the PR head, the changed files and the replies.
6. Repeat from step 2 until a review has **no actionable comments**.
7. **Merge** only when the owner says so. Then **clean up**: `git fetch --prune`, remove worktrees, fast-forward the default branch, and then `git branch -d` the merged branch (`-D` after a squash or rebase merge, once GitHub shows the PR as merged).

## Principles

- **Trust only what's verified.** An agent's report is a claim. Check the result yourself (comment lines, commit IDs, changed files, replies) before telling anyone it's done. This loop exists because an early reviewer reported deleting comments it never deleted.
- **Approvals belong to the owner, given to the manager.** Decisions such as merging come from the owner's own words to the manager. If a permission check blocks an action, no agent works around it; the manager tells the owner which permission rule is missing.
- **Isolate parallel work.** Sessions that share a checkout don't switch its branch under each other. Use `git worktree` for a second branch and remove the worktree afterwards.
- **Small, honest diffs.** Docs describe what exists. Planned work is labelled as planned.
- **Learn from each round.** After each round, judge whether the agents did a great job. If they did and the task will recur, capture it as a skill. If they didn't, fix the skill or the brief before the next round.

## Permissions

For the loop to run with the owner talking only to the manager, give each session only what its role needs:
- **Review:** post PR reviews (`gh api` POST to `repos/<owner>/<repo>/pulls/<n>/reviews`).
- **Implement:** push to feature branches, and reply to review comments (`gh api` POST to `repos/<owner>/<repo>/pulls/<n>/comments/<id>/replies`).

Keep these blocked unless the owner approves each one: approving PRs, requesting changes, merging, pushing to the default branch, and deleting anything on GitHub.

**A path-based allow rule can't keep approving blocked.** An approval is the same `POST .../pulls/<n>/reviews` call as a comment-only review; only the `event` field differs (`COMMENT`, `APPROVE` or `REQUEST_CHANGES`). So a rule that allows posting reviews also allows approving and requesting changes. To guard against that, either:
- add an auto-mode classifier rule that allows review posts only with `event` `COMMENT`, or
- add a PreToolUse hook that rejects any review post whose `event` is not `COMMENT`.

Without one of these, the owner accepts that review-posting permission also allows approving.

Example `.claude/settings.local.json` (replace `<owner>/<repo>`; check the keys against your Claude Code version):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/<owner>/<repo>/pulls/*/reviews *)",
      "Bash(gh api repos/<owner>/<repo>/pulls/*/comments/*/replies *)"
    ]
  },
  "autoMode": {
    "allow": [
      "Posting a PR review with gh api is allowed only when its event is COMMENT; never APPROVE or REQUEST_CHANGES."
    ]
  }
}
```

In practice, put the review rule only in the review session's settings and the replies rule only in the implement session's settings. Pushing to feature branches needs its own rule.

## Skills across providers

Skills live once in `skills/`. `.claude/skills` (Claude), `.agents/skills` (Codex) and `.github/skills` (Copilot) are symlinks to that directory, so the copies can't drift apart. See [`skills/README.md`](../skills/README.md), including the Windows note.

## Adopting this in another repository

1. Copy `skills/` and this file.
2. Create the symlinks:
   ```bash
   for d in .claude .agents .github; do mkdir -p $d; [ -e $d/skills ] && [ ! -L $d/skills ] && { echo "move $d/skills into skills/ first"; continue; }; ln -sfn ../skills $d/skills; done
   ```
3. On GitHub, turn on **Automatically delete head branches**.
4. Ask your manager agent to "run the review/implement loop on PR N".
