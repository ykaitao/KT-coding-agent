# Skills

The skills live here. `.agents/skills`, `.claude/skills` and `.github/skills` are symlinks to this directory, so each agent provider finds the same files.

**Windows:** Git checks out symlinks as plain text files containing `../skills` unless `core.symlinks=true` is set and symlinks are allowed (Developer Mode or admin rights). To get real symlinks, enable one of those and clone with `git clone -c core.symlinks=true <url>`. If you already cloned, run `git config core.symlinks true` and then `git checkout -- .agents/skills .claude/skills .github/skills`.

## Skills

- [`pr-review-loop`](pr-review-loop/SKILL.md): the manager's loop that alternates review and implement rounds until a review is clean.
- [`pr-inline-review`](pr-inline-review/SKILL.md): review a PR with line-checked inline comments.
- [`pr-address-review`](pr-address-review/SKILL.md): address review comments, push, and reply in each thread.

The overall process is described in [`docs/WAY_OF_WORKING.md`](../docs/WAY_OF_WORKING.md).

## Verifying discovery

First run the structural check from the repo root. It confirms the three symlinks resolve to `skills/`, each `SKILL.md` has frontmatter with a `name` matching its folder and a non-empty `description`, and the list above matches the skill folders:

```bash
bash tests/skills-check.sh
```

Then check that each provider actually finds the skills. Open the repo root and ask:

- **Claude Code** (reads `.claude/skills`): ask "which skills are available?". All three skills above should be listed.
- **Codex CLI** (expected to read `.agents/skills`; unverified): `codex exec --sandbox read-only "list the skills available to you"`. The default model may be unsupported for your account; pass a supported one with `-m <model>`.
- **GitHub Copilot in VS Code** (expected to read `.github/skills`; unverified): in Copilot Chat agent mode, ask "which skills are available?".

Record each check:

| Date | Provider | Version | Result |
| --- | --- | --- | --- |
| 2026-11-07 | Claude Code (desktop app) | Opus 5.5 | All three skills listed |
| 2026-11-07 | Codex CLI | 0.145.0 | Not run: default model `gpt-6-luna` unsupported with a ChatGPT account |
| | GitHub Copilot (VS Code) | | Not yet checked |
