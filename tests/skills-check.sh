#!/usr/bin/env bash
# Checks that every provider sees the same, well-formed skills:
#   1. .claude/skills, .agents/skills and .github/skills are symlinks to skills/
#   2. each skills/*/SKILL.md has frontmatter with a matching name and a description
#   3. skills/README.md lists exactly the skills that exist
# Run from anywhere: bash tests/skills-check.sh
set -u

root="$(cd "$(dirname "$0")/.." && pwd -P)"
skills_dir="$root/skills"
failures=0

ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# 1. Provider symlinks.
for link in .claude/skills .agents/skills .github/skills; do
  path="$root/$link"
  if [ ! -L "$path" ]; then
    fail "$link is not a symlink"
  elif [ "$(cd "$path" 2>/dev/null && pwd -P)" != "$skills_dir" ]; then
    fail "$link does not resolve to skills/ (points to $(readlink "$path"))"
  else
    ok "$link -> skills/"
  fi
done

# 2. Frontmatter of each SKILL.md.
existing=""
for dir in "$skills_dir"/*/; do
  folder="$(basename "$dir")"
  existing="$existing $folder"
  file="$dir/SKILL.md"
  if [ ! -f "$file" ]; then
    fail "skills/$folder has no SKILL.md"
    continue
  fi
  if ! msg="$(python3 - "$file" "$folder" 2>&1 <<'PY'
import sys
path, folder = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines()
if not lines or lines[0].strip() != "---":
    sys.exit("no YAML frontmatter (first line is not ---)")
try:
    end = lines.index("---", 1)
except ValueError:
    sys.exit("frontmatter is not closed with ---")
fields = {}
key = None
for line in lines[1:end]:
    if ":" in line and not line[:1].isspace():
        key, _, value = line.partition(":")
        key = key.strip()
        fields[key] = value.strip().strip("'\"")
    elif key and line[:1].isspace():
        # Continuation of a block scalar (> or |) or a folded plain value.
        fields[key] += " " + line.strip()
for key, value in fields.items():
    # For a block scalar the value is the continuation lines, not the indicator.
    if value[:1] in (">", "|"):
        fields[key] = value.split(" ", 1)[1].strip() if " " in value else ""
if fields.get("name") != folder:
    sys.exit("name is %r, expected %r" % (fields.get("name"), folder))
if not fields.get("description"):
    sys.exit("description is missing or empty")
PY
  )"; then
    fail "skills/$folder/SKILL.md: $msg"
  else
    ok "skills/$folder/SKILL.md frontmatter"
  fi
done

# 3. README list matches the skill folders. Only the "## Skills" section counts.
section="$(awk '/^## /{in_list = ($0 == "## Skills"); next} in_list' "$skills_dir/README.md")"
listed="$(printf '%s\n' "$section" | sed -n 's/^- \[`\([^`]*\)`\].*/\1/p')"
for name in $(printf '%s\n' "$listed" | sort | uniq -d); do
  fail "README lists $name more than once"
done
for name in $listed; do
  if [ -f "$skills_dir/$name/SKILL.md" ]; then
    ok "README lists $name, which exists"
  else
    fail "README lists $name, but skills/$name/SKILL.md does not exist"
  fi
done
for name in $existing; do
  if printf '%s\n' "$listed" | grep -qx "$name"; then
    :
  else
    fail "skills/$name exists but is not listed in skills/README.md"
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all skills checks passed"
