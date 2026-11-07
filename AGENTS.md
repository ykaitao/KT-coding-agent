# AGENTS.md

Instructions for AI coding agents (Codex, Copilot, Claude Code and others) working in this repo.

## Purpose

KT-coding-agent is a manager-led review and implement loop for AI coding agents, in which every agent report is checked on GitHub.

## Where to look

- `skills/`: the skills, each in its own `SKILL.md`. `pr-inline-review` reviews a PR, `pr-address-review` addresses review comments, and `pr-review-loop` runs the loop. `.claude/skills`, `.agents/skills` and `.github/skills` are symlinks to this folder.
- `docs/WAY_OF_WORKING.md`: roles, the loop, principles and permissions.

## Rules for every agent

- **Reviews are comment-only.** Post reviews with event `COMMENT`. Never approve or request changes. Never merge, resolve threads or push to the default branch on your own initiative; merge only on the owner's explicit word.
- **Verify before reporting.** Re-fetch from GitHub (PR head SHA, comment lines, replies) and report only what you checked.
- **Stay in your assigned files.** Don't stage unrelated local changes; use `git add <path>`, never `git add -A`. Don't switch the branch of a shared checkout; use a `git worktree`.
- **Run the tests before pushing:**

  ```bash
  bash tests/skills-check.sh
  bash tests/review-event-guard-test.sh
  ```

## The comment-only rule outside Claude Code

The review-event guard (`.claude/hooks/review-event-guard.py`) blocks approvals and request-changes reviews, but only in Claude Code, and only when it's configured in Claude Code's settings. Codex, Copilot and other agents don't run it, so they must follow the comment-only rule themselves.
