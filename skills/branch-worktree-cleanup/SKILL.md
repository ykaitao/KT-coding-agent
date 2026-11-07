---
name: branch-worktree-cleanup
description: Audit Git branches and worktrees in a requested repository, identify useful unmerged work, and safely clean stale local state. Use when asked to audit or clean branches/worktrees; include PR and issue follow-up only when requested.
---

# Branch and worktree cleanup

Audit the repository the user named or the repository in the current working directory. The skill works in any repository, but it does not authorize scanning every repository on the machine. For the routine cleanup right after one PR merges, follow the "Finish" step of [`pr-review-loop`](../pr-review-loop/SKILL.md); use this skill for a broader audit.

## Safety and scope

- Follow the user's scope and the repository's `AGENTS.md`, `CLAUDE.md`, or equivalent instructions. Do not assume the default branch is `main`, `master`, or `origin/*`.
- Separate local branches, remote-tracking refs, actual remote branches, pull requests, and worktrees. A stale `origin/*` ref is local metadata; it does not prove that a server branch still exists.
- Read status in every relevant worktree before deleting anything. Preserve the primary checkout, every checked-out branch, detached worktree HEADs, and any worktree containing tracked, untracked, or potentially valuable ignored files. Do not force-remove a worktree or force-delete a branch to get past a safety check.
- A cleanup request authorizes cleanup within its stated scope. Do not mutate GitHub (close/reopen PRs, delete remote branches, create/reopen issues, or post comments) unless the user requested those actions. Do not close an issue just because its branch has no unmerged commits; close it only when its actual scope is complete and the user authorized issue updates.
- Do not run tests unless the user asks. Respect project command wrappers and shell instructions when present.
- If the value or fate of unique work is uncertain, keep it and report why.

## Workflow

### 1. Establish the repository and base

1. Confirm the repository root and requested branch/worktree scope. Read applicable local agent instructions before acting.
2. Identify the default branch from the remote's symbolic `HEAD` (for example, `git symbolic-ref --short refs/remotes/origin/HEAD`). If unavailable, inspect repository metadata or ask rather than guessing.
3. If a current comparison matters and network access is available, fetch the chosen remote's default branch. Use `git fetch --prune <remote>` only when the user also asked to clean stale remote-tracking refs; pruning affects local tracking refs, not server branches.
4. Record the current checkout and worktree list before cleanup so the final report can distinguish what changed from what was preserved.
5. Record a space baseline before deleting anything, so the report can say how much was freed:
   ```bash
   df -k "$(git rev-parse --show-toplevel)" | tail -1          # free space on the repository's volume
   git count-objects -v | grep -E '^size(-pack)?:'             # object store: loose KB and pack KB
   git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r w; do du -sk "$w"; done   # per-worktree KB, ignored files (node_modules, venv, dist, databases) included
   ```

### 2. Inventory branches and worktrees

Inspect all branch refs in the requested scope, not only the current branch. Useful commands include:

```bash
git branch -avv
git for-each-ref --format='%(refname:short) %(objectname:short) %(upstream:short) %(subject)' refs/heads refs/remotes
git worktree list --porcelain
git status --short --branch
```

For each worktree, inspect status from that worktree's path. Before removing a worktree, also check ignored files (`git status --short --ignored`) so local data or caches are not silently discarded.

### 3. Decide whether each branch contains useful unmerged work

Compare each non-default branch to the selected default branch. Use commit counts and patch comparison as clues, then inspect the actual content:

```bash
git rev-list --left-right --count <default>...<branch>
git log --left-right --cherry-pick --oneline <default>...<branch>
git cherry -v <default> <branch>
git diff --stat <default>...<branch>
```

Interpret these carefully:

- A branch can be many commits behind without having useful unmerged work.
- Squash merges and rebases can make useful changes appear as different commits. Check whether the behavior, files, and tests already exist on the default branch, and inspect linked merged PRs when available.
- `git cherry` marks patch-equivalent commits, but does not by itself assess the value of a change or every merge-resolution change. Inspect relevant merge commits with `git show --remerge-diff` when needed.
- Review unique commits and resulting content, not just branch names, ahead counts, or old commit subjects. Classify real work as **useful and unfinished**, **already implemented**, **superseded**, **no meaningful change**, or **uncertain**.

For each branch with possible unique work, inspect its PR and issue references when GitHub access is available. Search by head branch, PR title/body, commit messages, and issue links. Confirm current PR and issue states; do not infer them from local tracking refs.

### 4. Handle unfinished work

Keep branches that contain useful unfinished work unless the user explicitly directs otherwise. Find the issue that best owns the remaining work:

- If no issue exists, create one only when the user authorized issue creation. Search first to avoid duplicates.
- If an issue exists but is closed and its work remains, reopen it only when authorized.
- If an issue is already open, add or improve its instructions only when authorized; avoid duplicate comments when clear instructions already exist.
- Give the implementing agent a bounded, implementable task: identify the affected behavior or code area, list concrete changes, state acceptance criteria, and suggest focused verification. Name completed work and non-goals so agents do not redo it. Do not write vague requests such as “finish the feature” or “clean up the code.”
- Leave a useful source branch available for the implementing agent. Do not reopen a PR automatically; the user's instruction must cover that action.

### 5. Remove work with no remaining value

For a branch verified to have no useful unfinished work:

- Close an associated **open** PR only if the user authorized PR changes. Already merged or closed PRs need no state change.
- Delete the local branch only if it is not checked out in any worktree and its unique content is confirmed implemented, superseded, or intentionally discarded within the user's scope. Prefer `git branch -d` for merged work; use `-D` only when the user authorized deletion and the audit confirms the unique commits have no value.
- Delete the actual remote branch only when remote deletion is in the user's scope. Verify the live remote ref first; `git branch -dr` only removes local tracking metadata.
- Remove a worktree only when worktree cleanup is in scope, the checkout is not primary or active, and its status (including ignored files) shows nothing to preserve. Remove the worktree before deleting its branch. Never use `--force` as routine cleanup.
- If a stale worktree registration points to a missing directory, verify the path is absent before pruning its metadata.

Measure each worktree with `du -sk <absolute path>` immediately before removing it and add it to a running total; the size includes ignored build output, virtualenvs and databases, which is where most of the space is. A worktree that needs its own untracked, regenerable directory (such as a venv) deleted first is still removed this way: delete only that exact absolute path, never `rm -rf` a path built from a variable that can be empty. Deleting a branch frees almost nothing: its commits stay in the object store through the reflog and any other ref until `git gc --prune=now`, which also ends reflog recovery, so run it only if the user asks.

When a no-value branch is checked out or has local files, preserve it and report the exact worktree path and what prevents safe deletion. Do not detach it or remove the worktree merely to make branch deletion possible.

## Completion report

Always include a space line: the total KB/MB of worktree directories removed (with the largest few), the change in `git count-objects -v` (usually none, say so), and the `df` free-space change on the volume, labelled approximate because other processes write to the disk too. If nothing was removed, say 0 freed. Also name the largest preserved worktrees and their sizes as what could be reclaimed later, and say if a size was not measured.

Report the repository and base used, how many branches/worktrees were audited, useful work retained, local/remote refs or worktrees removed, any PR/issue actions taken, and all preserved items with reasons. Link GitHub issues and PRs directly when available. State whether any branches remain unaudited or ambiguous.
