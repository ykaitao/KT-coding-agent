#!/usr/bin/env bash
# Tests for install.sh. Run from anywhere: bash tests/install-test.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd -P)"
installer="$root/install.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
# The installer's conflict check reads user skill folders: point it at scratch ones, never ~/.
export KT_SKILLS_USER_DIRS="$tmp/home/.claude/skills"

ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
check() { # check <description> <command...>
  local what=$1; shift
  if "$@"; then ok "$what"; else bad "$what"; fi
}
new_repo() { mkdir -p "$tmp/$1" && git -C "$tmp/$1" init -q && echo "$tmp/$1"; }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -print | sort && find . -path ./.git -prune -o -type f -exec cksum {} + | sort); }
is_link() { [ -L "$1/$2/skills" ] && [ "$(readlink "$1/$2/skills")" = "../skills" ]; }

# 1. Clean repo: everything installed, both checks pass.
t="$(new_repo clean)"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "clean: exit 0" [ "$code" -eq 0 ]
for f in skills/README.md skills/pr-review-loop/SKILL.md docs/WAY_OF_WORKING.md AGENTS.md \
  .claude/hooks/review-event-guard.py tests/review-event-guard-test.sh tests/skills-check.sh \
  tests/skills-conflicts.sh; do
  check "clean: $f copied" [ -f "$t/$f" ]
done
for d in .claude .agents .github; do check "clean: $d/skills symlink" is_link "$t" "$d"; done
check "clean: settings has the hook" grep -q "review-event-guard.py" "$t/.claude/settings.local.json"
check "clean: both checks reported ok" [ "$(grep -c '^ok   tests/' <<<"$out")" -eq 2 ]

# 2. Idempotent rerun: exit 0, nothing changes.
before="$(snapshot "$t")"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "rerun: exit 0" [ "$code" -eq 0 ]
check "rerun: no file changed" [ "$before" = "$(snapshot "$t")" ]
check "rerun: nothing copied, linked or written again" [ -z "$(grep -E '^(copy|link|write) ' <<<"$out")" ]

# 3. Existing skills/: README and existing skill kept, missing skills added, merge hint, non-zero.
t="$(new_repo existing-skills)"
mkdir -p "$t/skills/myskill" "$t/skills/pr-review-loop"
printf -- '---\nname: myskill\ndescription: Mine.\n---\n' > "$t/skills/myskill/SKILL.md"
printf 'mine\n' > "$t/skills/pr-review-loop/SKILL.md"
printf '# My skills\n\n## Skills\n\n- [`myskill`](myskill/SKILL.md): mine.\n' > "$t/skills/README.md"
readme_before="$(cat "$t/skills/README.md")"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "existing skills: README untouched" [ "$readme_before" = "$(cat "$t/skills/README.md")" ]
check "existing skills: existing skill untouched" [ "$(cat "$t/skills/pr-review-loop/SKILL.md")" = "mine" ]
check "existing skills: missing skill copied" [ -f "$t/skills/pr-inline-review/SKILL.md" ]
check "existing skills: skip reported" grep -q "skipped skills/pr-review-loop" <<<"$out"
check "existing skills: merge hint printed" grep -q "add the new skills to your skills/README.md" <<<"$out"
check "existing skills: exit non-zero (skills check fails until merged)" [ "$code" -ne 0 ]
check "existing skills: failure is the skills check" grep -q '^FAIL tests/skills-check.sh' <<<"$out"
check "existing skills: guard tests still pass" grep -q '^ok   tests/review-event-guard-test.sh' <<<"$out"

# 4. Existing settings without the hook (and an existing AGENTS.md): files untouched, block printed.
t="$(new_repo existing-settings)"
mkdir -p "$t/.claude"
printf '{ "permissions": { "allow": [] } }\n' > "$t/.claude/settings.local.json"
printf 'my agents\n' > "$t/AGENTS.md"
settings_before="$(cat "$t/.claude/settings.local.json")"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "existing settings: exit 0" [ "$code" -eq 0 ]
check "existing settings: file untouched" [ "$settings_before" = "$(cat "$t/.claude/settings.local.json")" ]
check "existing AGENTS.md: untouched" [ "$(cat "$t/AGENTS.md")" = "my agents" ]
check "existing settings: block printed" grep -q "CLAUDE_PROJECT_DIR/.claude/hooks/review-event-guard.py" <<<"$out"

# 5. Dry run: nothing changes, exit 0.
t="$(new_repo dry)"
before="$(snapshot "$t")"
out="$(bash "$installer" --dry-run "$t" 2>&1)"; code=$?
check "dry run: exit 0" [ "$code" -eq 0 ]
check "dry run: nothing changed" [ "$before" = "$(snapshot "$t")" ]
check "dry run: says what it would do" grep -q "^would copy skills/" <<<"$out"
check "dry run: runs the conflict check" grep -q "skills conflicts: .* 0 same-name" <<<"$out"

# 6. Not a Git repo root: refused, nothing written.
mkdir -p "$tmp/plain"
bash "$installer" "$tmp/plain" >/dev/null 2>&1; code=$?
check "non-git: exit non-zero" [ "$code" -ne 0 ]
check "non-git: nothing written" [ -z "$(ls -A "$tmp/plain")" ]
t="$(new_repo sub)"; mkdir -p "$t/inner"
bash "$installer" "$t/inner" >/dev/null 2>&1; code=$?
check "subdirectory of a repo: exit non-zero" [ "$code" -ne 0 ]
check "subdirectory of a repo: nothing written" [ -z "$(ls -A "$t/inner")" ]
check "subdirectory of a repo: repo root untouched" [ "$(ls -A "$t" | sort | tr '\n' ' ')" = ".git inner " ]

# 7. Existing symlink pointing elsewhere: kept, reported.
t="$(new_repo other-link)"
mkdir -p "$t/.claude" "$t/mine"
ln -s ../mine "$t/.claude/skills"
out="$(bash "$installer" "$t" 2>&1)"
check "other symlink: kept" [ "$(readlink "$t/.claude/skills")" = "../mine" ]
check "other symlink: reported" grep -q "skipped .claude/skills: it is a symlink to ../mine" <<<"$out"

# 8. Missing python3 or jq: refused before anything is written.
bin="$tmp/bin"; mkdir -p "$bin"
for tool in bash sh git cp mkdir ln dirname readlink grep cat; do
  ln -s "$(command -v "$tool")" "$bin/$tool"
done
t="$(new_repo no-tools)"
out="$(PATH="$bin" "$(command -v bash)" "$installer" "$t" 2>&1)"; code=$?
check "missing tools: exit non-zero" [ "$code" -ne 0 ]
check "missing tools: names python3" grep -q "needs python3" <<<"$out"
check "missing tools: nothing written" [ "$(ls -A "$t")" = ".git" ]

# 9. A personal skill with the same name: warned, install still succeeds.
mkdir -p "$tmp/home/.claude/skills/pr-review-loop"
printf -- '---\nname: pr-review-loop\ndescription: My own.\n---\n' > "$tmp/home/.claude/skills/pr-review-loop/SKILL.md"
t="$(new_repo conflict)"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "conflict: exit 0 (warning only)" [ "$code" -eq 0 ]
check "conflict: same-name warning printed" grep -q "WARN same name (folder and name): pr-review-loop" <<<"$out"
check "conflict: Claude Code winner named" grep -q "Claude Code loads the personal copy" <<<"$out"
rm -rf "$tmp/home"

is_real_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }

# 10. Existing real .claude/skills and .agents/skills: one link per skill, nothing replaced.
t="$(new_repo real-skill-dirs)"
mkdir -p "$t/.claude/skills/team-notes" "$t/.agents/skills"
printf 'ours\n' > "$t/.claude/skills/team-notes/SKILL.md"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "real skill dirs: exit 0" [ "$code" -eq 0 ]
check "real skill dirs: own skill untouched" [ "$(cat "$t/.claude/skills/team-notes/SKILL.md")" = "ours" ]
for d in .claude .agents; do
  check "real skill dirs: $d/skills still a real directory" is_real_dir "$t/$d/skills"
  for s in "$root"/skills/*/; do
    name="$(basename "$s")"
    check "real skill dirs: $d/skills/$name links to skills/$name" [ "$(readlink "$t/$d/skills/$name")" = "../../skills/$name" ]
  done
done
check "real skill dirs: .github/skills symlink" is_link "$t" .github
check "real skill dirs: skills check passes" grep -q '^ok   tests/skills-check.sh' <<<"$out"
before="$(snapshot "$t")"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "real skill dirs rerun: exit 0" [ "$code" -eq 0 ]
check "real skill dirs rerun: nothing changed" [ "$before" = "$(snapshot "$t")" ]
check "real skill dirs rerun: nothing linked again" [ -z "$(grep -E '^(copy|link|write|add) ' <<<"$out")" ]

# 11. A project skill with the same name in a real folder: kept, reported, never replaced.
t="$(new_repo real-skill-dir-collision)"
mkdir -p "$t/.claude/skills/pr-review-loop"
printf 'ours\n' > "$t/.claude/skills/pr-review-loop/SKILL.md"
out="$(bash "$installer" "$t" 2>&1)"; code=$?
check "collision in real dir: project copy untouched" [ "$(cat "$t/.claude/skills/pr-review-loop/SKILL.md")" = "ours" ]
check "collision in real dir: not a link" [ ! -L "$t/.claude/skills/pr-review-loop" ]
check "collision in real dir: reported" grep -q "skipped .claude/skills/pr-review-loop: it already exists" <<<"$out"
check "collision in real dir: other skills linked" [ -L "$t/.claude/skills/pr-inline-review" ]
check "collision in real dir: exit non-zero" [ "$code" -ne 0 ]
check "collision in real dir: failure is the skills check" grep -q '^FAIL tests/skills-check.sh' <<<"$out"

# 12. .claude/settings.local.json is git-ignored through .git/info/exclude, once.
t="$(new_repo exclude)"
bash "$installer" "$t" >/dev/null 2>&1
check "exclude: settings file ignored" git -C "$t" check-ignore -q .claude/settings.local.json
check "exclude: listed in .git/info/exclude" grep -qx "/.claude/settings.local.json" "$t/.git/info/exclude"
check "exclude: settings file not untracked" [ -z "$(git -C "$t" status --porcelain --untracked-files=all .claude/settings.local.json)" ]
out="$(bash "$installer" "$t" 2>&1)"
check "exclude rerun: line not added twice" [ "$(grep -cx "/.claude/settings.local.json" "$t/.git/info/exclude")" -eq 1 ]
check "exclude rerun: reported as already ignored" grep -q "already ignored" <<<"$out"
t="$(new_repo exclude-gitignore)"
printf '.claude/settings.local.json\n' > "$t/.gitignore"
exclude_before="$(cat "$t/.git/info/exclude" 2>/dev/null)"
bash "$installer" "$t" >/dev/null 2>&1
check "exclude: left alone when .gitignore already covers it" [ "$exclude_before" = "$(cat "$t/.git/info/exclude" 2>/dev/null)" ]
t="$(new_repo exclude-dry)"
exclude_before="$(cat "$t/.git/info/exclude" 2>/dev/null)"
bash "$installer" --dry-run "$t" >/dev/null 2>&1
check "exclude: dry run leaves it alone" [ "$exclude_before" = "$(cat "$t/.git/info/exclude" 2>/dev/null)" ]

# 13. Next-step hints: AGENTS.md merge hint when one exists, and the permissions step.
t="$(new_repo hints)"
printf 'my agents\n' > "$t/AGENTS.md"
out="$(bash "$installer" "$t" 2>&1)"
check "hints: AGENTS.md merge hint" grep -q "AGENTS.md already existed: add a link to docs/WAY_OF_WORKING.md" <<<"$out"
check "hints: permissions next step" grep -q "^next step: add the allow rules .*Permissions" <<<"$out"
t="$(new_repo no-agents-hint)"
out="$(bash "$installer" "$t" 2>&1)"
check "hints: no AGENTS.md hint on a clean install" [ -z "$(grep 'AGENTS.md already existed' <<<"$out")" ]

exit "$fail"
