---
name: propose-skill
description: Turn a user's private experience (notes, transcripts, an internal skill) into a new public skill for this repo without leaking anything, then propose it as a pull request. Use when asked to contribute, share or upstream a skill or lesson.
---

# Propose a skill

You turn private experience into a public skill. The private source never leaves the user's machine. Only principles you restate in your own words, and a skill you write fresh from them, go into the repo.

## Rules

- **Never copy or paste private text** into the skill, the PR, a commit message or a comment. That includes names, paths, issue numbers, product terms and example data.
- **Never commit or upload the scratchpad.** Keep it outside the repo (for example in your session's scratch directory or `/tmp`). Don't attach it to the PR, and don't quote it in chat beyond what the user already showed you.
- **Report counts, not matches.** When a check finds a problem, report how many and in which file, not the matched private text.
- If the user's source is someone else's work, stop unless it's MIT-compatible and the user can name the author for attribution. Otherwise, link to the original instead of adapting it.

## Steps

1. **Read the source locally.** Ask the user for the private notes or skill, and what problem the new skill should solve and when it should trigger. Check `skills/README.md` for an existing skill that already covers it; if one does, propose an edit to that skill instead.
2. **Distill.** In a scratchpad file outside the repo, write one-line principles: each a generic rule that would hold in any project, with no names, numbers or specifics. Drop any principle you can't state without private detail. Show the list to the user and agree on it.
3. **Write fresh.** Create `skills/<name>/SKILL.md` from the principles alone, without the source open. Use a lowercase, hyphenated `<area>-<action>` name, and frontmatter with `name` (matching the folder) and a one-sentence `description` that says what it does and when to use it. Any examples must be invented and neutral (for example `example-org/example-app`, `alice`, `PR 123`). Add the skill to the list in `skills/README.md` under `## Skills`.
4. **Check it's clean.**
   - Run `bash tests/skills-check.sh`. It must pass. Where the repo's check scans skills for leaks (home paths, emails, tokens, references to other repos, and the user's private terms from their local, uncommitted terms file), make sure the user's terms file exists so that part runs too, and fix every hit.
   - Check that no run of 6 words is shared with the source. This prints only a count:

     ```bash
     python3 - <private-source-file> skills/<name>/SKILL.md <<'PY'
     import re, sys
     words = lambda p: re.findall(r"[a-z0-9']+", open(p, encoding="utf-8").read().lower())
     runs = lambda w: {tuple(w[i:i + 6]) for i in range(len(w) - 5)}
     shared = runs(words(sys.argv[1])) & runs(words(sys.argv[2]))
     print(f"{len(shared)} shared 6-word runs")
     sys.exit(1 if shared else 0)
     PY
     ```

     If it reports any, rewrite those passages in new words and rerun until it reports 0. Run it against every source file.
   - Reread the diff (`git diff`) as a stranger would: nothing should hint at who the user is or what they work on.
5. **Propose.** Commit only the new skill and the `skills/README.md` line, on a new branch from an up-to-date default branch. Push it and open a draft PR from the skill template, `gh pr create --draft --template skill.md`, filling in every item. Report the PR URL to the user.
6. **Review.** The PR goes through the review loop like code (`pr-review-loop`, with `pr-inline-review` and `pr-address-review`). Ask the reviewer to also check for leaks, overlap with existing skills, and whether the triggers in the description can be tested.

## Report

The PR URL, the principles you used, the `skills-check.sh` result, the shared 6-word run count (0) for each source file, and anything you couldn't check (for example, no private terms file).
