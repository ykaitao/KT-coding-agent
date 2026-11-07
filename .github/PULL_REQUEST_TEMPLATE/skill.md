# New or changed skill

<!-- How to use this template: GitHub applies it only on request. On the web, add ?template=skill.md to the compare URL, for example https://github.com/<owner>/<repo>/compare/master...<branch>?template=skill.md. From the CLI, copy this file, fill it in, and pass it with gh pr create --body-file <file>. -->

**Skill:** `skills/<name>/SKILL.md`

**Category:** <!-- one of: pr, code, design, release, repo -->

**Status:** <!-- one of: experimental, stable, deprecated -->

## Problem and trigger

<!-- What problem does the skill solve, and when should an agent use it? -->

## Principles

<!-- The one-line generic principles the skill was written from. No private names, paths, numbers or quotes. -->

-

## Checklist

- [ ] This is my own work, or it is MIT-compatible and the original author is credited.
- [ ] The skill was written fresh from the principles above, not edited down from private text.
- [ ] `bash tests/skills-check.sh` passes, including the leak check (and my local private-terms check, if I have one).
- [ ] No run of 6 words is shared with the private source (count: 0).
- [ ] The skill is listed in `skills/README.md`.
- [ ] If the status is `stable`: a fixture or behaviour test covers it (path: ).

## Tests run

<!-- Commands and results. Report leak-check counts only, never the matched text. -->
