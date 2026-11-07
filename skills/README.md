# Skills

The skills live here. `.agents/skills`, `.claude/skills` and `.github/skills` are symlinks to this directory, so each agent provider finds the same files.

**Windows:** Git checks out symlinks as plain text files containing `../skills` unless `core.symlinks=true` is set and symlinks are allowed (Developer Mode or admin rights). In that case, clone with `git clone -c core.symlinks=true <url>`. If you already cloned, run `git config core.symlinks true` and then `git checkout -- .agents .claude .github`.
