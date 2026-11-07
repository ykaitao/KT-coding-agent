#!/usr/bin/env bash
# Tests for install.sh. Run from anywhere: bash tests/install-test.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd -P)"
installer="$root/install.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

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
  .claude/hooks/review-event-guard.py tests/review-event-guard-test.sh tests/skills-check.sh; do
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

exit "$fail"
