#!/usr/bin/env bash
# Installs the skills, docs, review-event guard and checks into another Git repository.
# Usage: bash install.sh [--dry-run] <target-repo-dir>
# Never overwrites an existing file. With --dry-run it only prints what it would do.
set -u

src="$(cd "$(dirname "$0")" && pwd -P)"
dry=0
target=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) target="$arg" ;;
  esac
done
if [ -z "$target" ]; then
  echo "usage: bash install.sh [--dry-run] <target-repo-dir>" >&2
  exit 2
fi
for tool in git python3 jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: install.sh needs $tool (the guard hook needs python3; the checks also need git and jq)" >&2
    exit 1
  fi
done
if [ ! -d "$target" ]; then
  echo "error: $target is not a directory" >&2
  exit 1
fi
target="$(cd "$target" && pwd -P)"
top="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || top=""
if [ -z "$top" ] || [ "$(cd "$top" && pwd -P)" != "$target" ]; then
  echo "error: $target is not the root of a Git repository" >&2
  exit 1
fi
if [ "$target" = "$src" ]; then
  echo "error: target is this repository itself" >&2
  exit 1
fi

[ "$dry" = 1 ] && echo "dry run: nothing will be changed"

# do_ <description> <command...>: runs the command, or only describes it in a dry run.
do_() {
  local what=$1; shift
  if [ "$dry" = 1 ]; then echo "would $what"; else "$@" && echo "$what"; fi
}

copy_file() { # copy_file <path relative to the repo root>
  local rel=$1
  if [ -e "$target/$rel" ] || [ -L "$target/$rel" ]; then
    echo "skipped $rel (already exists)"
  else
    do_ "copy $rel" sh -c 'mkdir -p "$(dirname "$2")" && cp "$1" "$2"' _ "$src/$rel" "$target/$rel"
  fi
}

# 1. Skills.
manual_merge=0
if [ ! -e "$target/skills" ]; then
  do_ "copy skills/" cp -R "$src/skills" "$target/skills"
else
  for dir in "$src"/skills/*/; do
    name="$(basename "$dir")"
    if [ -e "$target/skills/$name" ]; then
      echo "skipped skills/$name (already exists)"
    else
      do_ "copy skills/$name" cp -R "$src/skills/$name" "$target/skills/$name"
    fi
  done
  if [ ! -e "$target/skills/README.md" ]; then
    copy_file skills/README.md
  else
    echo "skipped skills/README.md (already exists)"
    manual_merge=1
  fi
fi

# 2. Docs, guard hook and checks.
for rel in docs/WAY_OF_WORKING.md AGENTS.md .claude/hooks/review-event-guard.py \
  tests/review-event-guard-test.sh tests/skills-check.sh tests/skills-conflicts.sh; do
  copy_file "$rel"
done

# 3. Provider symlinks, refusing to replace a real skills directory.
for d in .claude .agents .github; do
  link="$target/$d/skills"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "../skills" ]; then
    echo "skipped $d/skills (symlink already in place)"
  elif [ -L "$link" ]; then
    echo "skipped $d/skills: it is a symlink to $(readlink "$link"), not ../skills; change it by hand"
  elif [ -e "$link" ]; then
    echo "skipped $d/skills: it exists and is not a symlink; move its contents into skills/ first"
  else
    do_ "link $d/skills -> ../skills" sh -c 'mkdir -p "$1" && ln -sfn ../skills "$1/skills"' _ "$target/$d"
  fi
done

# 4. Hook settings. Never edits an existing file.
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
  do_ "write .claude/settings.local.json with the guard hook" sh -c 'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"' _ "$settings" "$hook_block"
elif grep -q "review-event-guard.py" "$settings"; then
  echo "skipped .claude/settings.local.json (already has the guard hook)"
else
  echo "skipped .claude/settings.local.json (exists without the guard hook). Merge this block into it by hand:"
  printf '%s\n' "$hook_block"
fi

if [ "$manual_merge" = 1 ]; then
  echo "skills/ already existed: add the new skills to your skills/README.md under '## Skills', using the entries in $src/skills/README.md"
fi
echo "add the allow rules for each role: see 'Permissions' in docs/WAY_OF_WORKING.md"

# 5. Checks.
# conflicts <skills dir>: warns about clashes with the user's own skills; never fails the install.
conflicts() {
  echo "checking for conflicts with your own skills (names and paths only):"
  bash "$src/tests/skills-conflicts.sh" --repo-skills "$1" 2>&1 | sed 's/^/  /'
}
if [ "$dry" = 1 ]; then
  echo "would run tests/review-event-guard-test.sh and tests/skills-check.sh"
  conflicts "$src/skills"
  exit 0
fi
status=0
for t in tests/review-event-guard-test.sh tests/skills-check.sh; do
  if (cd "$target" && bash "$t" >/dev/null 2>&1); then
    echo "ok   $t"
  else
    echo "FAIL $t (run 'bash $t' in $target for details)"
    status=1
  fi
done
conflicts "$target/skills"
exit "$status"
