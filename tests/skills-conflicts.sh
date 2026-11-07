#!/usr/bin/env bash
# Reports skills in the user's own skill folders that have the same name as one of this
# repo's skills, and says which copy each provider loads.
# A user skill matches when its folder name or its frontmatter name equals a repo
# skill's folder name or frontmatter name.
# It doesn't look for near-duplicate descriptions: word overlap scored distinct skills
# higher than a reworded copy, so it can't tell them apart.
# Read-only. From each user skill it reads only the name in the SKILL.md frontmatter,
# and only when the frontmatter is closed by a --- line. It prints only names and paths.
# Usage: bash tests/skills-conflicts.sh [--strict] [--repo-skills DIR] [--user-dirs DIR:DIR...]
# User dirs default to $KT_SKILLS_USER_DIRS, or else ~/.claude/skills, ~/.agents/skills
# and ~/.copilot/skills. Exits 0 with warnings; with --strict, exits 1 if any name collides.
set -u

usage() { echo "usage: bash tests/skills-conflicts.sh [--strict] [--repo-skills DIR] [--user-dirs DIR:DIR...]" >&2; exit 2; }
root="$(cd "$(dirname "$0")/.." && pwd -P)"
repo_skills="$root/skills"
user_dirs="${KT_SKILLS_USER_DIRS:-$HOME/.claude/skills:$HOME/.agents/skills:$HOME/.copilot/skills}"
strict=0
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) strict=1 ;;
    --repo-skills) [ $# -ge 2 ] || usage; repo_skills=$2; shift ;;
    --user-dirs) [ $# -ge 2 ] || usage; user_dirs=$2; shift ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift
done

python3 -I - "$repo_skills" "$user_dirs" "$strict" <<'PY'
import os, sys

repo_dir, user_dirs, strict = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

# Which copy wins on a same-name collision, by the provider that reads the user folder.
# Source: the provider table in issue 32 (Claude Code and Codex skills docs; Copilot's
# rule isn't documented).
WINNER = {
    ".claude": "Claude Code loads the personal copy; it overrides the repo's",
    ".agents": "Codex doesn't merge them, so both copies can appear; Copilot's rule isn't documented",
    ".copilot": "Copilot's rule isn't documented",
}
MAX_LINES = 40

def front_name(path):
    """The frontmatter name, or None. Reads only up to the closing --- and never the body."""
    with open(path, encoding="utf-8", errors="replace") as f:
        if f.readline().strip() != "---":
            return None
        lines = []
        for _ in range(MAX_LINES):
            line = f.readline()
            if not line:
                return None  # no closing ---: treat as no frontmatter
            if line.strip() == "---":
                break
            lines.append(line)
        else:
            return None  # not closed within the limit: treat as no frontmatter
    for line in lines:
        if not line[:1].isspace() and line.partition(":")[0].strip() == "name":
            return line.partition(":")[2].strip().strip("'\"") or None
    return None

def skills(d):
    """[(folder, frontmatter name or None, path)] for each skill folder in d."""
    out = []
    if not os.path.isdir(d):
        return out
    for entry in sorted(os.listdir(d)):
        path = os.path.join(d, entry, "SKILL.md")
        if os.path.isfile(path):
            out.append((entry, front_name(path), os.path.join(d, entry)))
    return out

def provider(d):
    parent = os.path.basename(os.path.dirname(os.path.abspath(d)))
    return WINNER.get(parent, "not a documented skills folder for Claude Code, Codex or Copilot; check your provider's docs")

repo = skills(repo_dir)
repo_names = {}
for folder, name, path in repo:
    for key in {folder, name} - {None}:
        repo_names.setdefault(key, path)
repo_real = os.path.realpath(repo_dir)
collisions = 0
dirs = [d for d in user_dirs.split(":") if d]
for d in dirs:
    if os.path.realpath(d) == repo_real:
        continue
    for folder, name, upath in skills(d):
        if os.path.realpath(upath).startswith(repo_real + os.sep):
            continue  # a link back to this repo's own skill, not a second copy
        hits = sorted({k for k in (folder, name) if k in repo_names})
        if hits:
            collisions += 1
            how = "folder and name" if folder in hits and name in hits else ("folder" if folder in hits else "name")
            print(f"WARN same name ({how}): {hits[0]}: {upath} and {repo_names[hits[0]]}. {provider(d)}.")

print(f"skills conflicts: {len(repo)} repo skills, {len(dirs)} user folders, {collisions} same-name")
sys.exit(1 if strict and collisions else 0)
PY
