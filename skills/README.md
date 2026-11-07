# Skills

The skills live here. `.agents/skills`, `.claude/skills` and `.github/skills` are symlinks to this directory, so each agent provider finds the same files.

**Windows:** Git checks out symlinks as plain text files containing `../skills` unless `core.symlinks=true` is set and symlinks are allowed (Developer Mode or admin rights). To get real symlinks, enable one of those and clone with `git clone -c core.symlinks=true <url>`. If you already cloned, run `git config core.symlinks true` and then `git checkout -- .agents/skills .claude/skills .github/skills`.

## Skills

- [`pr-review-loop`](pr-review-loop/SKILL.md): the manager's loop that alternates review and implement rounds until a review is clean.
- [`pr-inline-review`](pr-inline-review/SKILL.md): review a PR with line-checked inline comments.
- [`pr-address-review`](pr-address-review/SKILL.md): address review comments, push, and reply in each thread.

The overall process is described in [`docs/WAY_OF_WORKING.md`](../docs/WAY_OF_WORKING.md).
