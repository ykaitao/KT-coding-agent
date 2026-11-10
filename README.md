# KT-coding-agent

Helps developers deliver high-quality software faster with AI coding tools such as Claude Code, Codex and GitHub Copilot. Today it is a documented way of working: shared agent skills that run pull requests through review and implement rounds, plus guardrails and checks around them.

## What works today

| Asset | What it does |
| --- | --- |
| [`skills/pr-review-loop`](skills/pr-review-loop/SKILL.md) | The manager's loop: use owner-visible review and implement sessions, alternate rounds until a review is clean, then merge on the owner's word. |
| [`skills/pr-inline-review`](skills/pr-inline-review/SKILL.md) | Review a PR and post line-checked inline comments as one `COMMENT` review. |
| [`skills/pr-address-review`](skills/pr-address-review/SKILL.md) | Address review comments, push, and reply in each thread. |
| [`docs/WAY_OF_WORKING.md`](docs/WAY_OF_WORKING.md) | The process: roles, principles, permissions and how to adopt it. |
| [`.claude/hooks/review-event-guard.py`](.claude/hooks/review-event-guard.py) and [its tests](tests/review-event-guard-test.sh) | A Claude Code PreToolUse hook that blocks PR reviews whose event isn't `COMMENT`, so review permission can't approve. |
| [`tests/skills-check.sh`](tests/skills-check.sh) | Checks the provider symlinks, visible-session default, each `SKILL.md`'s frontmatter, and the skill list in [`skills/README.md`](skills/README.md). |
| [CI](.github/workflows/ci.yml) | On every PR and push to `master`: the review-event guard tests and Markdown lint. |

Skills live once in `skills/`; `.claude/skills`, `.agents/skills` and `.github/skills` are symlinks to the same source, so provider copies cannot drift. Structural symlinks are checked by `tests/skills-check.sh`; runtime skill discovery is a separate check. Claude Code discovery is confirmed, while Codex and GitHub Copilot discovery remains **unverified**; see [Verifying discovery](skills/README.md#verifying-discovery). The review-loop skill directs managers to use owner-visible sessions in the active host by default.

## Quick start (about 5 minutes)

Adopt the skills and the guard in another Git repository. You need `git`, `bash`, `python3`, `jq`, and the GitHub CLI `gh`, signed in (`gh auth status`) with access to the repository.

1. Clone this repo next to yours and go to your repo's root:

   ```bash
   git clone https://github.com/ykaitao/KT-coding-agent.git ../KT-coding-agent
   ```

2. Copy the files. If your repo already has a `skills/` folder, this copies only the three skill folders, skips any that already exist, and leaves your `skills/README.md` alone. In that case, add the three entries from [`skills/README.md`](skills/README.md) to your own `skills/README.md` under `## Skills`:

   ```bash
   mkdir -p docs .claude/hooks tests
   if [ -e skills ]; then for s in pr-review-loop pr-inline-review pr-address-review; do if [ -e skills/$s ]; then echo "skills/$s exists, skipped"; else cp -R ../KT-coding-agent/skills/$s skills/; fi; done; echo "skills/ already existed: add the three skills to skills/README.md under ## Skills"; else cp -R ../KT-coding-agent/skills .; fi
   cp ../KT-coding-agent/docs/WAY_OF_WORKING.md docs/
   cp ../KT-coding-agent/.claude/hooks/review-event-guard.py .claude/hooks/
   cp ../KT-coding-agent/tests/review-event-guard-test.sh ../KT-coding-agent/tests/skills-check.sh tests/
   ```

3. Create the symlinks (this refuses to replace an existing `skills` directory):

   ```bash
   for d in .claude .agents .github; do mkdir -p $d; [ -e $d/skills ] && [ ! -L $d/skills ] && { echo "move $d/skills into skills/ first"; continue; }; ln -sfn ../skills $d/skills; done
   ```

4. Add the hook to `.claude/settings.local.json`. If the file already exists, merge the `hooks` block in by hand instead:

   ```bash
   [ -e .claude/settings.local.json ] && echo "merge the hooks block by hand" || cat > .claude/settings.local.json <<'EOF'
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/review-event-guard.py\"" }
           ]
         }
       ]
     }
   }
   EOF
   ```

5. Add the `allow` rules for each role from [Permissions](docs/WAY_OF_WORKING.md#permissions) to the same file. Without them, every review post and reply asks for approval, so the loop can't run unattended. `.claude/settings.local.json` isn't committed: it belongs to you and to this checkout, so repeat steps 4 and 5 on each machine and in each new worktree.

6. Run both checks. Every line should start with `ok`, and each script exits 0:

   ```bash
   bash tests/review-event-guard-test.sh
   ```

   ```bash
   bash tests/skills-check.sh
   ```

7. Open a PR, start a Claude Code session as the manager, and ask it to "run the review/implement loop on PR N".

The review-event guard is a Claude Code hook, so it runs only in Claude Code. Codex and Copilot sessions get the skills (discovery unverified) but no guard, and GitHub has no permission that allows review comments but not approvals. Either give them read-only access and have the manager post their reviews, or treat comment-only as a working agreement: a human checks their reviews, and only the owner decides to merge.

The full adoption notes, including turning on **Automatically delete head branches** on GitHub, are in [Adopting this in another repository](docs/WAY_OF_WORKING.md#adopting-this-in-another-repository).

## Roadmap (planned, not yet implemented)

Tracked in [#5](https://github.com/ykaitao/KT-coding-agent/issues/5) and [#10](https://github.com/ykaitao/KT-coding-agent/issues/10).

- **Deep scanning:** specialised agents that review code health, architecture and data models, cloud and token cost, and UI accessibility.
- **Issue lifecycle:** turn findings into well-scoped GitHub issues, then run them through implement and review agents.
- **Memory and learning:** keep successful approaches as reusable skills and remember the owner's standards and preferences.
- **Verification and human in the loop:** back every patch with tests or other evidence, and stop to ask the owner when a trade-off is unclear.
