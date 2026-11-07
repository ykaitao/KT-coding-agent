#!/usr/bin/env bash
# Installs the review/implement loop into another git repo.
# Usage: bash install.sh [--dry-run] <target-repo-dir>
# Copies the skills, the doc, the review-event guard hook and its tests, creates the
# provider symlinks and .claude/settings.local.json, then runs the tests in the target.
# It never overwrites an existing file; anything it can't do safely it prints for you to do by hand.
set -u

usage() { echo "usage: bash install.sh [--dry-run] <target-repo-dir>" >&2; exit 2; }

dry_run=0
target=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $arg" >&2; usage ;;
    *) [ -z "$target" ] || usage; target="$arg" ;;
  esac
done
[ -n "$target" ] || usage

src="$(cd "$(dirname "$0")" && pwd -P)"
if [ ! -d "$target" ]; then
  echo "refusing: $target is not a directory" >&2; exit 1
fi
target="$(cd "$target" && pwd -P)"
top="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || top=""
if [ -z "$top" ] || [ "$(cd "$top" && pwd -P)" != "$target" ]; then
  echo "refusing: $target is not the root of a git repo" >&2; exit 1
fi
if [ "$target" = "$src" ]; then
  echo "refusing: target is this repo" >&2; exit 1
fi

[ "$dry_run" -eq 1 ] && echo "dry run: nothing will be changed"
run() { # print an action and do it unless --dry-run
  echo "+ $*"
  [ "$dry_run" -eq 1 ] || "$@"
}

copy_file() { # path relative to both repos
  local rel=$1
  if [ -e "$target/$rel" ] || [ -L "$target/$rel" ]; then
    echo "skip $rel (exists)"
  else
    run mkdir -p "$(dirname "$target/$rel")"
    run cp -p "$src/$rel" "$target/$rel"
  fi
}

# 1. Skills.
if [ ! -e "$target/skills" ]; then
  run cp -Rp "$src/skills" "$target/skills"
else
  skipped=""
  for dir in "$src"/skills/*/; do
    name="$(basename "$dir")"
    if [ -e "$target/skills/$name" ]; then
      skipped="$skipped skills/$name"
    else
      run cp -Rp "$src/skills/$name" "$target/skills/$name"
    fi
  done
  echo "skills/ already exists, so skills/README.md was not copied."
  echo "  Merge by hand: add each skill folder from $src/skills to the \"## Skills\" list in $target/skills/README.md."
  if [ -n "$skipped" ]; then
    echo "  Skipped (already exist):$skipped"
    echo "  Compare them with $src/skills and merge by hand, e.g. diff -r $src/skills/<name> $target/skills/<name>"
  fi
fi

# 2. Doc, hook and tests.
for rel in docs/WAY_OF_WORKING.md .claude/hooks/review-event-guard.py \
           tests/review-event-guard-test.sh tests/skills-check.sh; do
  copy_file "$rel"
done

# 3. Provider symlinks. Never replace a real directory or a different link.
for link in .claude/skills .agents/skills .github/skills; do
  path="$target/$link"
  if [ -L "$path" ]; then
    if [ "$(readlink "$path")" = "../skills" ]; then
      echo "skip $link (symlink exists)"
    else
      echo "warning: $link is a symlink to $(readlink "$path"), not ../skills; fix it by hand" >&2
    fi
  elif [ -e "$path" ]; then
    echo "warning: $link exists and is not a symlink; move its contents into skills/ and replace it with a link to ../skills by hand" >&2
  else
    run mkdir -p "$(dirname "$path")"
    run ln -s ../skills "$path"
  fi
done

# 4. Hook in .claude/settings.local.json.
hook_block='{
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
}'
settings="$target/.claude/settings.local.json"
if [ ! -e "$settings" ]; then
  echo "+ write .claude/settings.local.json with the review-event guard hook"
  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$target/.claude"
    printf '%s\n' "$hook_block" > "$settings"
  fi
elif grep -q 'review-event-guard.py' "$settings"; then
  echo "skip .claude/settings.local.json (already has the hook)"
else
  echo ".claude/settings.local.json exists without the hook; it was not changed."
  echo "  Merge this block into it by hand:"
  printf '%s\n' "$hook_block" | sed 's/^/    /'
fi
echo "Next: add the allow rules for each role from docs/WAY_OF_WORKING.md#permissions to .claude/settings.local.json."

# 5. Tests in the target.
if [ "$dry_run" -eq 1 ]; then
  echo "+ bash tests/review-event-guard-test.sh (in $target)"
  echo "+ bash tests/skills-check.sh (in $target)"
  exit 0
fi
status=0
for t in tests/review-event-guard-test.sh tests/skills-check.sh; do
  echo "+ bash $t"
  if ! (cd "$target" && bash "$t"); then
    echo "FAILED: $t" >&2
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "installed into $target" || echo "installed into $target, but tests failed (see above)" >&2
exit "$status"
