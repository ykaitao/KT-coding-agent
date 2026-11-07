---
name: pr-address-review
description: Address inline review comments on a GitHub pull request by editing the PR branch, pushing, and replying in each thread. Use when asked to fix or implement review feedback in an implement/review loop.
---

# Address PR review comments

## Steps
1. Read the comments: `gh api --paginate repos/<owner/repo>/pulls/<n>/comments --jq '.[] | {id, line, path, body, in_reply_to_id}'`. Work only on top-level comments (`in_reply_to_id` is null) that no later entry replies to yet. Comments are labelled `must-fix` or `nit`; address the ones your brief lists, which in a loop are the must-fix ones plus any nits the manager sent in the final round.
2. Run `git fetch` first. Any new branch or worktree starts from an up-to-date `origin/<default>`, never from a local default branch, which may be stale. Work on the PR head branch in your own worktree: if the current branch already is that branch, use it; otherwise run `gh pr checkout <n>` in a dedicated worktree. Never switch branches in a shared checkout. In Claude Code, as your first command, run `echo pulls/0/reviews -X POST`: the review-event guard hook (from `.claude/settings.local.json` in your worktree) must block it. If it isn't blocked, or the file is missing, the guard is off: stop and report it before doing any work. Other agents don't run the guard (see `AGENTS.md`): skip the probe and follow the comment-only rule yourself. Make the smallest edit that addresses each comment, and apply `suggestion` blocks as given unless they're wrong (if so, say why in your reply).
3. Touch only the files the comments concern. Never stage unrelated local changes; use `git add <path>`, never `git add -A`.
4. Test before pushing. Run the project's tests that cover the change. For a security fix, test every reported bypass plus the cases that must still be allowed, and list each input with its result in the report.
5. Commit with a clear message, adding any attribution trailer the environment requires, and push to the PR branch.
6. Reply in each thread with how it was addressed and the commit SHA: `gh api repos/<owner/repo>/pulls/<n>/comments/<id>/replies -f body=...`.
7. Verify: re-fetch the PR and confirm the head SHA and that every reply landed. Never report an action you haven't verified.

## Rules
- Do not resolve threads, approve, or merge.
- No bare `@mentions`.

## Report
The commit SHA, one line per comment saying what changed, and the tests you ran with their results.
