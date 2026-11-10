---
name: pr-review-loop
description: Run a pull request through owner-visible review and implement sessions until a review finds no actionable comments, then merge on the owner's word and clean up. Use when asked to "run the review/implement loop" on a PR.
---

# PR review loop (manager)

You orchestrate and are the owner's only point of contact: relay their decisions to the sessions, and never send them to another session to answer. Two owner-visible sessions do the work: **review** follows `pr-inline-review` and **implement** follows `pr-address-review`. Reuse suitable visible sessions in the current project when they are idle and authorized for this task. Create a new visible task/thread or worktree only when the owner's request explicitly authorizes that action; otherwise stop and ask the owner for that specific authorization or ask them to start the visible session. Ask the owner before falling back to hidden/background agents. Never silently switch to hidden/background agents or implement in a shared checkout to bypass missing authorization. Keep stable handles (`implement`, `implement1`, `review`, `review1`) and set each title to `<handle>: <task>` when the host supports renaming. The owner must be able to open each session and read its task and progress.

## Visible sessions across agent hosts

Use the host's visible conversation or task-session mechanism. First inspect the project's existing visible sessions and read the most recent status. Do not interrupt an active, unrelated task or create a duplicate when a suitable session already exists. Continue or start a session only when the owner's authorization covers that action. If no suitable authorized session exists, stop and ask the owner for authorization to create one or ask them to start it. Send the brief to the chosen session and keep the manager as the owner's only contact.

- **Codex desktop:** use the Codex app's thread tools. Call `list_threads` and `read_thread` to find and check existing project sessions; continue a suitable idle session only when the owner's request authorizes the follow-up; rename it with `set_thread_title` when authorized. Call `create_thread` only when the human explicitly asks for a new visible task/thread. If no suitable authorized session exists, stop and ask the owner to explicitly authorize a new visible thread or start it themselves. A `create_thread` request that also targets a worktree requires explicit authorization for that worktree too. Do not substitute a hidden agent or shared checkout when authorization is missing.
- **Claude desktop:** reuse or start the named visible sessions in the desktop app only when the owner's request authorizes that action. Otherwise ask the owner to authorize or start the visible session. Keep each session in its assigned role and use the same stable-handle naming convention.
- **Other hosts:** use that provider's owner-visible conversation or foreground task session only when authorized. If the host offers no visible-session mechanism, tell the owner and ask before using hidden/background delegation.

If the manager cannot access the host's visible-session controls, pause and explain the limitation instead of silently falling back to hidden agents. Messaging or creating a session must be within the owner's task authorization.

## Brief each session for one task

For every new or resumed session, make the latest manager prompt the explicit task boundary: name the repository, issue or PR, deliverable, allowed external services or calls (with a request cap when relevant), and exclusions. Prior session history, issue discussions, saved memory, and approvals do not authorize a different task or carry over to a new assignment. If a resumed session starts following stale instructions, stop it and re-brief it before it reads other issues, calls external services, or edits files. Production reads are external actions too; production access and paid API calls need owner authorization for the current task, and retries count against any approved cap. The manager remains the owner's only contact and relays any question or needed authorization.

## Parallel pairs

To run several PRs at once, give each one its own pair (for example `implement1`/`review1`), and only run as many pairs as you can verify properly; two worked well. Free disk space limits it too, since each authorized implement session needs its own worktree: before starting another pair, check free space with `df -h .` and start it only if that exceeds the size of one existing worktree (`du -sh <worktree>`) plus its build output, and remove each worktree and its branches right after its PR merges (see "Finish").

- Pick work whose PRs touch different files, and tell each implement session which files to stay out of.
- Each authorized implement session gets its own worktree and branch (see "Worktrees"). Review sessions only read through `gh`, so they can share the main checkout and its settings.

## Worktrees

Run each implement session in its own isolated worktree when the owner's request authorizes creating or selecting that worktree, so it never switches a shared checkout's branch. If worktree authorization is missing, stop and ask the owner for that specific authorization or ask them to start the visible session in an isolated worktree. Use the host's managed worktree tool when available, or create a worktree from an up-to-date remote base and give the visible implement session its exact path. Never use a shared checkout as a workaround.

- Untracked files such as `.claude/settings.local.json` aren't copied into new worktrees, so a worktree session would run without that file's allow rules and without the review-event guard hook: nothing would stop it from posting an `APPROVE` or `REQUEST_CHANGES` review, and its thread replies may need approval.
- Once worktree creation is authorized, for Claude Code create it before the session starts (`git fetch` then `git worktree add -b <branch> <path> origin/<base>` for a new PR, never from a stale local default branch; or `git fetch` then `git worktree add <path> <branch>` for an existing one), copy the file in (`cp .claude/settings.local.json <path>/.claude/`), and confirm it's there (`ls <path>/.claude/settings.local.json`). Start that session with `<path>` as its working directory. Codex and other hosts should use their managed worktree feature when available, or be given the exact isolated worktree path, only after the owner has authorized it. Never make an implementer switch a shared checkout's branch.
- `ls` only shows the file exists, not that the guard runs. As the session's first command, have it run `echo pulls/0/reviews -X POST`: the guard must block it ("no event found in a review write"), while a session without the guard just prints the text. If the file is missing or the probe isn't blocked, the guard is off: stop the session and don't use it. This applies to Claude Code sessions only. Other agents (Codex, Copilot) don't run the guard (see `AGENTS.md`), so skip the copy and the probe for them and brief them to follow the comment-only rule themselves.

## Loop
1. Ask review to review PR `<n>` at its current head. Brief it with the repo, the PR, the head SHA, what changed since the last round, and "label each comment `must-fix` or `nit`; report the review URL, the number of must-fix and nit comments, and the line, label and gist for each".
2. When review reports back, **check it**: fetch the review and its comments (`gh api --paginate .../pulls/<n>/comments`), confirm the head SHA and that each comment's `line` holds the text it's about.
   - Check each label. A security, correctness, data-loss or permission issue is always `must-fix`; relabel any such `nit`, and the other way round for a trivial `must-fix`. Note any change in your report.
   - If there are 0 must-fix comments (the body says "No actionable comments." or "No must-fix comments", and no inline comment is labelled must-fix after your check), the review loop is done. For open nits, decide: if they're cheap and useful, take them as one final batch for implement; otherwise skip them. After the batch, review the new head once: only must-fix findings from that review continue the loop, and any new nits are skipped. Record the call (which nits, and why) for your report to the owner, then go to "Finish".
   - If review's post was blocked, read its saved draft and check that its `event` is `COMMENT`, its `commit_id` is the PR head, and every comment's `line` holds the text it's about. Then post it if your own permissions allow it. If you're blocked too, don't work around it: tell the owner which permission rule is missing (see "Permissions" in `docs/WAY_OF_WORKING.md`). The owner talks only to you, so never ask them to answer inside another session.
   - Sessions started before a settings change may not pick it up. If they're still blocked after a rule is added, start fresh sessions.
3. Send the must-fix comments (IDs, paths, lines, gists) to implement with the file scope and the rules: only touch these files, don't stage unrelated edits, and work only in its own worktree. Hold nits for the final round.
4. When implement reports back, **check it**: confirm the new PR head, the changed files, the edits and one reply per comment. For security fixes, rerun the tests yourself; don't rely on the report alone. Then go back to step 1.

Keep the loop bounded: only must-fix comments keep it going, and the final nit round doesn't count. If must-fix comments are still open after 4 rounds, report to the owner what's left and ask whether to continue. Security code may need more rounds; say so when it does.

After each round, judge each agent's work. If something went wrong, improve the skill or the brief before the next round. If the work went well and the task will recur, propose a new skill. If the reviewer dropped a concern you raised, or the implementer skipped tests, fix the skill, not just the next brief.

For a guardrail (a hook, a validator, a lint) where each round finds rarer bypasses, the loop may stop only when every reproduced bypass is either fixed or explicitly accepted by the owner as a known limit; the reviewer can't waive one alone. Have implement list each accepted bypass, with its exact input, under "Known limits" in the code or docs, and tell the owner that human approval of each PR, not the guardrail, is the real control.

## Finish
- Check that the PR's description matches its code at the final head: what it says it adds, the numbers and examples it quotes, and its limits. If they differ, have implement update the description before you ask to merge.
- PRs that add a line to the same list (for example `skills/README.md`) conflict with each other. Right before merging each one, update its branch (`gh pr update-branch <n> --repo <owner/repo>`, or merge the base by hand if that conflicts), and wait for CI on the new head. The update adds a merge commit, so the head moves: if the merge only adds the other PRs' list lines, check that diff and CI; otherwise send it back for a review round.
- A PR opened before a CI workflow existed has no checks yet. After that workflow merges, run `gh pr update-branch <n> --repo <owner/repo>`, preferably before the last review round. It adds a merge commit, so the head moves: review the new head (at least the merged-in diff), confirm checks at that head, and tell implement to pull before its next push.
- A PR isn't ready to merge until its checks pass. Confirm it with `gh pr checks <n> --repo <owner/repo>` at the final head before asking the owner to merge. If a check fails, send the failure to implement as another round. If checks are pending, wait (`gh pr checks <n> --repo <owner/repo> --watch`) before asking.
- Report to the owner: rounds run, final review URL, check results, the nits you sent or skipped and why, and anything left unverified. Merge only on their word.
- After the merge, run `git fetch --prune`, remove any worktrees for the branch, fast-forward the default branch, then `git branch -d <branch>` (`-D` after a squash or rebase merge, once GitHub shows the PR as merged). Also delete the local branches that worktree sessions created (for example `claude/<name>`) once their worktrees are removed, and check `git branch -vv` for any marked `[gone]`.

## Rules
- Run each `gh api` read of a PR's reviews as its own command. The guard hook treats a command that mentions a reviews endpoint as a write if any part uses a flag outside `gh api`'s read flags (for example `head -n` or `git log --oneline`), and then blocks it if it is chained (`;`, `&&`, `|` and so on). Chains whose parts use only read flags get through, so don't read a pass as the hook being broken. It can also block a shell command whose text merely mentions a reviews endpoint, such as a heredoc that edits these docs; use a file-editing tool for those edits.
- Never approve, resolve threads, or merge on your own initiative.
- Never report something to the owner that you haven't checked on GitHub.
