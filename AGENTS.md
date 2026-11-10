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
- **Use authorized owner-visible agent sessions by default.** Reuse suitable visible review and implement conversations in the current provider's task UI when they are authorized for this task. Create a new visible task/thread or worktree only when the owner's request explicitly authorizes that action; otherwise stop and ask the owner for that specific authorization or ask them to start the visible session. Ask the owner before falling back to hidden/background agents. Never silently switch to hidden/background agents or implement in a shared checkout to bypass missing authorization.
- **Use the current task boundary.** At the start of each assignment, follow the latest manager brief for the repository, issue/PR, files and allowed actions. Prior turns, memory, issue discussions and approvals are context, not authorization to work elsewhere. If a resumed session points to a different task, stop and report to the manager before reading or acting outside the current scope. Read-only production access and paid API calls require owner authorization for the current task; retries count against any approved cap.
- **Stay in your assigned files.** Don't stage unrelated local changes; use `git add <path>`, never `git add -A`. Don't switch the branch of a shared checkout; use an isolated `git worktree` when authorized, and ask the owner if that authorization is missing.
- **When your own skill and this repo's skill cover the same task:** an explicit instruction from the user or owner wins first, then this repo's skills and docs for work in this repo, then the more specific skill. No skill relaxes the safety rules here: comment-only reviews, and no merge without the owner. Name the conflict in your report instead of choosing silently, and ask the owner if it's unclear. In Claude Code, a personal skill with the same name silently replaces this repo's copy, so you won't see the conflict: before using one of this repo's skills, check whether `~/.claude/skills/<name>/` exists. If it does, read this repo's `skills/<name>/SKILL.md` directly, follow it for work in this repo, and say so in your report. In Codex, both copies appear. Copilot's rule isn't documented; treat any same-name skill as a conflict.
- **Run the tests before pushing:**

  ```bash
  bash tests/skills-check.sh
  bash tests/review-event-guard-test.sh
  ```

## The comment-only rule outside Claude Code

The review-event guard (`.claude/hooks/review-event-guard.py`) blocks approvals and request-changes reviews, but only in Claude Code, and only when it's configured in Claude Code's settings. Codex, Copilot and other agents don't run it, so they must follow the comment-only rule themselves.
