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

**A path-based allow rule can't keep approving blocked.** An approval is the same `POST .../pulls/<n>/reviews` call as a comment-only review; only the `event` field differs (`COMMENT`, `APPROVE` or `REQUEST_CHANGES`). So a rule that allows posting reviews also allows approving and requesting changes.

**The guard is a PreToolUse hook** that rejects any review post whose `event` isn't `COMMENT`. It has to find `event` where it really is: in the `--input` file or in `-f`/`-F event=` arguments.

An auto-mode classifier rule doesn't replace the hook. A command that matches a `permissions.allow` rule runs without reaching the classifier, so once the review allow rule exists, the classifier never judges review posts. Without an allow rule, every post costs a classifier call that may be denied, and with `--input <file>` the `event` isn't in the command text the classifier sees. Without the hook, the owner accepts that review-posting permission also allows approving.

Example hook, saved as `.claude/hooks/review-event-guard.py`. It blocks writes to `.../pulls/<n>/reviews...` unless every `event` it can find is `COMMENT`, and it also blocks when it can't read the event (no event, or `--input -`). Reads such as `GET .../reviews` pass.

```python
#!/usr/bin/env python3
# PreToolUse hook: block any GitHub PR review post whose event is not COMMENT.
import json, os, re, shlex, sys

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")
if not re.search(r"pulls/\d+/reviews\b", cmd):
    sys.exit(0)
try:
    tokens = shlex.split(cmd)
except ValueError:
    tokens = cmd.split()

writes, events = False, []
for i, t in enumerate(tokens):
    nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
    if t in ("-X", "--method") and nxt.upper() != "GET":
        writes = True
    if t in ("-f", "-F", "--field", "--raw-field"):
        writes = True
        if nxt.startswith("event="):
            events.append(nxt[len("event="):])
    if t == "--input":
        writes = True
        try:
            path = os.path.join(data.get("cwd", "."), nxt)
            events.append(json.load(open(path)).get("event"))
        except Exception:
            events.append(None)  # stdin or unreadable file: can't tell

if writes and (not events or any(e != "COMMENT" for e in events)):
    print("Blocked: PR reviews may only be posted with event COMMENT.", file=sys.stderr)
    sys.exit(2)
```

Example `.claude/settings.local.json` (replace `<owner>/<repo>`; check the keys against your Claude Code version):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh api repos/<owner>/<repo>/pulls/*/reviews *)",
      "Bash(gh api repos/<owner>/<repo>/pulls/*/comments/*/replies *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/review-event-guard.py\"" }
        ]
      }
    ]
  },
  "autoMode": {
    "allow": [
      "$defaults",
      "Posting a PR review with gh api is allowed only when its event is COMMENT; never APPROVE or REQUEST_CHANGES."
    ]
  }
}
```

`.claude/settings.local.json` applies to everyone working in that folder. To give review only the review rule and implement only the replies rule, run each role in its own worktree, each with its own `.claude/settings.local.json`. If the sessions share one folder, both rules apply to both sessions. Pushing to feature branches needs its own rule.

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
