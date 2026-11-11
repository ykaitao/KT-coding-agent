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

# 3. Provider symlinks. A provider folder that is already a real directory keeps its
# contents and gets one link per skill instead; nothing in it is replaced.
skill_names() { # the skills that will be in skills/ after the install
  { for dir in "$src"/skills/*/ "$target"/skills/*/; do [ -f "$dir/SKILL.md" ] && basename "$dir"; done; } | sort -u
}
for d in .claude .agents .github; do
  link="$target/$d/skills"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "../skills" ]; then
    echo "skipped $d/skills (symlink already in place)"
  elif [ -L "$link" ]; then
    echo "skipped $d/skills: it is a symlink to $(readlink "$link"), not ../skills; change it by hand"
  elif [ -d "$link" ]; then
    echo "$d/skills is a real directory: linking each skill into it"
    for name in $(skill_names); do
      entry="$link/$name"
      if [ -L "$entry" ] && [ "$(readlink "$entry")" = "../../skills/$name" ]; then
        echo "skipped $d/skills/$name (link already in place)"
      elif [ -e "$entry" ] || [ -L "$entry" ]; then
        echo "skipped $d/skills/$name: it already exists and isn't a link to skills/$name; the project's own copy wins, so rename one of them"
      else
        do_ "link $d/skills/$name -> ../../skills/$name" ln -s "../../skills/$name" "$entry"
      fi
    done
  elif [ -e "$link" ]; then
    echo "skipped $d/skills: it exists and is not a directory or symlink; remove or rename it"
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

# 5. Keep the per-user settings file out of commits, through the repo's local exclude file.
if git -C "$target" check-ignore -q .claude/settings.local.json; then
  echo "skipped git exclude: .claude/settings.local.json is already ignored"
else
  exclude="$(cd "$target" && git rev-parse --git-path info/exclude)"
  case "$exclude" in /*) ;; *) exclude="$target/$exclude" ;; esac
  do_ "add .claude/settings.local.json to $(git -C "$target" rev-parse --git-path info/exclude) (local, never committed)" \
    sh -c 'mkdir -p "$(dirname "$1")" && printf "%s\n" "/.claude/settings.local.json" >> "$1"' _ "$exclude"
fi

if [ "$manual_merge" = 1 ]; then
  echo "skills/ already existed: add the new skills to your skills/README.md under '## Skills', using the entries in $src/skills/README.md"
fi
if ! cmp -s "$src/AGENTS.md" "$target/AGENTS.md" && [ -e "$target/AGENTS.md" ]; then
  echo "AGENTS.md already existed: add a link to docs/WAY_OF_WORKING.md and the 'Rules for every agent' from $src/AGENTS.md to yours"
fi
echo "next step: add the allow rules for each role from 'Permissions' in docs/WAY_OF_WORKING.md to .claude/settings.local.json, or every review post and reply will ask for approval"

# 6. Checks.
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
