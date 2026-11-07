#!/usr/bin/env bash
# Tests for install.sh against temporary git repos. Run from anywhere: bash tests/install-test.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd -P)"
installer="$root/install.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failures=0
ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
check() { # description, then a command that must succeed
  local desc=$1; shift
  if "$@"; then ok "$desc"; else fail "$desc"; fi
}

new_repo() { # name -> path of a fresh git repo
  local d="$tmp/$1"
  mkdir -p "$d" && git -C "$d" init -q && echo "$d"
}
install() { # dir [--dry-run]; output in $tmp/out, exit code in $code
  bash "$installer" "${@:2}" "$1" > "$tmp/out" 2>&1
  code=$?
}
snapshot() { # listing of every path with its type, link target and content hash
  (cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then echo "L $p -> $(readlink "$p")"
    elif [ -d "$p" ]; then echo "D $p"
    else echo "F $p $(cksum < "$p")"; fi
  done)
}
is_link() { [ -L "$1/$2" ] && [ "$(readlink "$1/$2")" = "../skills" ]; }
same() { cmp -s "$1" "$2"; }
out_has() { grep -qF -- "$1" "$tmp/out"; }

# 1. Clean repo: everything is installed and both test scripts pass.
r="$(new_repo clean)"
install "$r"
check "clean: exit 0" [ "$code" -eq 0 ]
check "clean: skills copied" same "$root/skills/README.md" "$r/skills/README.md"
for s in "$root"/skills/*/; do
  n="$(basename "$s")"
  check "clean: skills/$n copied" same "$root/skills/$n/SKILL.md" "$r/skills/$n/SKILL.md"
done
for f in docs/WAY_OF_WORKING.md .claude/hooks/review-event-guard.py tests/review-event-guard-test.sh tests/skills-check.sh; do
  check "clean: $f copied" same "$root/$f" "$r/$f"
done
for l in .claude/skills .agents/skills .github/skills; do
  check "clean: $l -> ../skills" is_link "$r" "$l"
done
check "clean: settings has the hook" grep -q 'review-event-guard.py' "$r/.claude/settings.local.json"
check "clean: settings is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$r/.claude/settings.local.json"
check "clean: test scripts ran and passed" out_has "all skills checks passed"

# 2. Rerun on the installed repo: nothing changes.
before="$(snapshot "$r")"
install "$r"
check "rerun: exit 0" [ "$code" -eq 0 ]
check "rerun: no changes" [ "$before" = "$(snapshot "$r")" ]
check "rerun: settings left alone" out_has "skip .claude/settings.local.json (already has the hook)"

# 3. Existing skills/ with its own skill and README: only missing skill folders are added.
r="$(new_repo existing-skills)"
first="$(basename "$(ls -d "$root"/skills/*/ | head -1)")"
mkdir -p "$r/skills/mine" "$r/skills/$first"
printf -- '---\nname: mine\ndescription: mine\n---\n' > "$r/skills/mine/SKILL.md"
echo "their own version" > "$r/skills/$first/SKILL.md"
printf '# Skills\n\n## Skills\n\n- [`mine`](mine/SKILL.md)\n' > "$r/skills/README.md"
cp "$r/skills/README.md" "$tmp/readme.orig"
install "$r"
check "existing skills: own skill kept" grep -q 'name: mine' "$r/skills/mine/SKILL.md"
check "existing skills: existing skill folder not overwritten" grep -qx "their own version" "$r/skills/$first/SKILL.md"
check "existing skills: README.md not overwritten" same "$tmp/readme.orig" "$r/skills/README.md"
for s in "$root"/skills/*/; do
  n="$(basename "$s")"
  [ "$n" = "$first" ] && continue
  check "existing skills: missing skills/$n added" same "$root/skills/$n/SKILL.md" "$r/skills/$n/SKILL.md"
done
check "existing skills: skip reported" out_has "Skipped (already exist): skills/$first"
check "existing skills: merge hint printed" out_has "Merge by hand"
# Their README doesn't list the new skills, so skills-check fails and so must the installer.
check "existing skills: exit non-zero when a test fails" [ "$code" -ne 0 ]

# 4. Existing settings file without the hook: left untouched, block printed.
r="$(new_repo existing-settings)"
mkdir -p "$r/.claude"
echo '{"permissions": {"allow": []}}' > "$r/.claude/settings.local.json"
cp "$r/.claude/settings.local.json" "$tmp/settings.orig"
mkdir -p "$r/docs" && echo "their own doc" > "$r/docs/WAY_OF_WORKING.md"
install "$r"
check "existing file: not overwritten" grep -qx "their own doc" "$r/docs/WAY_OF_WORKING.md"
check "existing file: skip reported" out_has "skip docs/WAY_OF_WORKING.md (exists)"
check "existing settings: exit 0" [ "$code" -eq 0 ]
check "existing settings: file unchanged" same "$tmp/settings.orig" "$r/.claude/settings.local.json"
check "existing settings: hook block printed" out_has '"PreToolUse"'
check "existing settings: merge hint printed" out_has "Merge this block into it by hand"

# 5. A real directory where a symlink belongs is not replaced.
r="$(new_repo real-dir)"
mkdir -p "$r/.github/skills" && echo keep > "$r/.github/skills/keep.txt"
install "$r"
check "real dir: not replaced" [ ! -L "$r/.github/skills" ] && check "real dir: contents kept" grep -qx keep "$r/.github/skills/keep.txt"
check "real dir: warning printed" out_has ".github/skills exists and is not a symlink"

# 6. --dry-run changes nothing.
r="$(new_repo dry-run)"
before="$(snapshot "$r")"
install "$r" --dry-run
check "dry run: exit 0" [ "$code" -eq 0 ]
check "dry run: no changes" [ "$before" = "$(snapshot "$r")" ]
check "dry run: actions printed" out_has "+ cp -Rp"

# 7. Not a git repo, or not its root: refused, nothing written.
d="$tmp/not-git"; mkdir -p "$d"
install "$d"
check "non-git: exit non-zero" [ "$code" -ne 0 ]
check "non-git: refused" out_has "refusing"
check "non-git: nothing written" [ -z "$(ls -A "$d")" ]
r="$(new_repo subdir)"; mkdir -p "$r/sub"
install "$r/sub"
check "subdir: refused" [ "$code" -ne 0 ] && check "subdir: nothing written" [ -z "$(ls -A "$r/sub")" ]

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all install checks passed"
